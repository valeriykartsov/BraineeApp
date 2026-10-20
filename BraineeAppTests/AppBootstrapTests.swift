//
//  AppBootstrapTests.swift
//  BraineeAppTests
//
//  Старт приложения на постоянном хранилище (roadmap SD-3): перенос JSON при первом запуске,
//  дальше данные только из хранилища — без очистки и без дублей (риск R1).
//  Всё во временных папках, отдельном Keychain service и отдельных UserDefaults.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
final class AppBootstrapTests {
    /// Исходные JSON и Keychain-копии.
    private let source: TemporaryDataStore
    /// Хранилище SwiftData, бэкапы и маркер.
    private let directory: URL
    private let defaultsSuite = "BraineeAppBootstrapTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        source = try TemporaryDataStore()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppBootstrapTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        // Не первая установка: applyAccentDefaults не переписывает profile.json.
        defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private var storeURL: URL { directory.appendingPathComponent("BraineeApp.store") }
    private var backupsDirectory: URL { directory.appendingPathComponent("Backups", isDirectory: true) }
    private var markerURL: URL { directory.appendingPathComponent("BraineeApp/swiftdata-migration.json") }

    private func makeMigrator(checkpoint: @escaping (JSONToSwiftDataMigrator.Stage) throws -> Void = { _ in }) -> JSONToSwiftDataMigrator {
        JSONToSwiftDataMigrator(
            locations: .init(source: source.location, backupsDirectory: backupsDirectory, markerURL: markerURL),
            checkpoint: checkpoint
        )
    }

    /// Один «запуск приложения»: новый контейнер на том же файле + bootstrap.
    /// Контейнер возвращается, чтобы тест держал его, пока работает с моделями.
    @discardableResult
    private func launch(
        checkpoint: @escaping (JSONToSwiftDataMigrator.Stage) throws -> Void = { _ in }
    ) throws -> ModelContainer {
        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        try AppDataPersistence.bootstrap(
            into: container.mainContext,
            location: source.location,
            migrator: makeMigrator(checkpoint: checkpoint),
            defaults: defaults
        )
        return container
    }

    private func count<T: PersistentModel>(_ type: T.Type, in container: ModelContainer) throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<T>())
    }

    private func backupFolders() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: backupsDirectory.path)) ?? []
    }

    private struct InjectedFailure: Error {}

    // MARK: - Первый запуск

    // Без маркера: данные переносятся из JSON, маркер ставится; JSON и Keychain не меняются.
    @Test func первыйЗапуск_переноситJSONИНеМеняетИсходники() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(original)
        try source.writeTasksKeychain(original)
        try PersistenceFixtures.encoder.encode(PersistenceFixtures.profileDocument()).write(to: source.profileFileURL)
        let tasksBefore = try Data(contentsOf: source.tasksFileURL)
        let profileBefore = try Data(contentsOf: source.profileFileURL)
        let keychainBefore = source.keychainData(account: AppDataStore.tasksFileName)

        let container = try launch()

        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: container.mainContext), original)
        #expect(try count(UserProfile.self, in: container) == 1)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
        #expect(backupFolders().count == 1)
        #expect(try Data(contentsOf: source.tasksFileURL) == tasksBefore)
        #expect(try Data(contentsOf: source.profileFileURL) == profileBefore)
        #expect(source.keychainData(account: AppDataStore.tasksFileName) == keychainBefore)
    }

    // Первая установка без данных: хранилище пустое, маркер ставится, ошибки нет.
    @Test func первыйЗапускБезДанных_пустоеХранилище() throws {
        let container = try launch()

        #expect(try count(TaskItem.self, in: container) == 0)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }

    // MARK: - Повторные запуски (R1)

    // С маркером: изменения в хранилище переживают перезапуск — ничего не удаляется и не дублируется.
    @Test func повторныйЗапуск_неУдаляетИНеДублируетДанные() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(original)
        let first = try launch()
        let context = first.mainContext
        context.insert(TaskItem(title: "Создана после переноса"))
        try context.save()

        for _ in 0..<2 {
            let relaunched = try launch()
            #expect(try count(TaskItem.self, in: relaunched) == original.tasks.count + 1)
            #expect(try count(TaskGroup.self, in: relaunched) == original.groups.count)
            #expect(try count(TaskTag.self, in: relaunched) == original.tags.count)
            #expect(try count(Habit.self, in: relaunched) == original.habits.count)
        }
        #expect(backupFolders().count == 1)
    }

    // С маркером JSON больше не читается: его изменение не попадает в хранилище (откат не поддерживается, D-19).
    @Test func повторныйЗапуск_JSONНеЧитается() throws {
        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        let first = try launch()
        let ids = Set(try first.mainContext.fetch(FetchDescriptor<TaskItem>()).map(\.uuid))

        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        let relaunched = try launch()

        #expect(Set(try relaunched.mainContext.fetch(FetchDescriptor<TaskItem>()).map(\.uuid)) == ids)
    }

    // MARK: - Ошибки

    // Сбой переноса: ошибка запуска, маркера нет; следующий запуск переносит заново без дублей.
    @Test func сбойПереноса_ошибкаИПовторПриСледующемЗапуске() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(original)

        #expect(throws: AppDataPersistence.BootstrapError.self) {
            try self.launch { stage in
                if stage == .saved { throw InjectedFailure() }
            }
        }
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))

        let container = try launch()
        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: container.mainContext), original)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }

    // Битый mytasks.json без Keychain-копии: ошибка один раз, файл сохранён; следующий запуск работает (BASE-3).
    @Test func битыйФайл_ошибкаОдинРазЗатемЗапускБезЗадач() throws {
        try Data("{ не json".utf8).write(to: source.tasksFileURL)

        #expect(throws: AppDataStoreError.self) {
            try self.launch()
        }
        #expect(source.corruptFiles(of: AppDataStore.tasksFileName).count == 1)
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))

        let container = try launch()
        #expect(try count(TaskItem.self, in: container) == 0)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }

    // MARK: - Хранилище

    // Хранилище приложения — в Application Support, не в Documents и не в App Group.
    @Test func адресХранилища_вApplicationSupport() {
        let path = ModelContainerFactory.standardStoreURL.path
        #expect(path.contains("/Library/Application Support/BraineeApp/BraineeApp.store"))
        #expect(!path.contains("/Documents/"))
    }
}
