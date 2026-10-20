//
//  AutoBackupTests.swift
//  BraineeAppTests
//
//  JSON — только бэкап (roadmap SD-4): правило автобэкапа (не чаще раза в 24 часа, последние 7 файлов)
//  и то, что изменение данных больше не перезаписывает mytasks.json и Keychain.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
final class AutoBackupTests {
    private let container: ModelContainer
    private let directory: URL
    private let original = PersistenceFixtures.fullTasksDocument()
    private let start = PersistenceFixtures.date(100_000)
    private let day: TimeInterval = 24 * 60 * 60

    init() throws {
        container = try TestHelpers.makeContainer()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppAutoBackupTests-\(UUID().uuidString)", isDirectory: true)
        AppDataPersistence.importTasks(original, into: container.mainContext)
        try container.mainContext.save()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private var backup: AutoBackup { AutoBackup(directory: directory) }

    // MARK: - Правило частоты

    // Бэкапа ещё не было — пора; меньше 24 часов — рано; 24 часа и больше — пора.
    @Test func правилоЧастоты_разВСутки() {
        #expect(AutoBackup.isDue(lastBackupAt: nil, now: start))
        #expect(!AutoBackup.isDue(lastBackupAt: start, now: start))
        #expect(!AutoBackup.isDue(lastBackupAt: start, now: start.addingTimeInterval(day - 1)))
        #expect(AutoBackup.isDue(lastBackupAt: start, now: start.addingTimeInterval(day)))
        #expect(AutoBackup.isDue(lastBackupAt: start, now: start.addingTimeInterval(3 * day)))
    }

    // Часы ушли назад (последний бэкап «в будущем») — бэкап делается, а не откладывается навсегда.
    @Test func часыУшлиНазад_бэкапДелается() {
        #expect(AutoBackup.isDue(lastBackupAt: start, now: start.addingTimeInterval(-60)))
    }

    // MARK: - Файлы

    // Первый уход в фон создаёт файл в формате ручного бэкапа (D-16) со всеми данными.
    @Test func первыйБэкап_файлВФорматеРучногоБэкапа() throws {
        let url = try #require(try backup.performIfDue(context: container.mainContext, now: start))

        #expect(url.lastPathComponent == AutoBackup.fileName(for: start))
        let document = try BackupDocument.decode(from: Data(contentsOf: url))
        #expect(document.exportedAt == start)
        RecordAssert.sameContent(document.tasks, original)
    }

    // Повторный уход в фон в те же сутки файл не создаёт; через сутки — создаёт.
    @Test func повторВТеЖеСутки_новогоФайлаНет() throws {
        try backup.performIfDue(context: container.mainContext, now: start)

        #expect(try backup.performIfDue(context: container.mainContext, now: start.addingTimeInterval(day - 60)) == nil)
        #expect(backup.backupFiles().count == 1)

        #expect(try backup.performIfDue(context: container.mainContext, now: start.addingTimeInterval(day)) != nil)
        #expect(backup.backupFiles().count == 2)
    }

    // Хранятся последние 7 файлов: старые удаляются, новые остаются.
    @Test func ротация_остаютсяПоследниеСемь() throws {
        for index in 0..<9 {
            try backup.performIfDue(context: container.mainContext, now: start.addingTimeInterval(Double(index) * day))
        }

        let names = backup.backupFiles().map(\.lastPathComponent)
        #expect(names == (2..<9).map { AutoBackup.fileName(for: start.addingTimeInterval(Double($0) * day)) })
    }

    // Ротация трогает только свои файлы: бэкап перед миграцией и посторонние файлы остаются.
    @Test func ротация_неТрогаетЧужиеФайлы() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let foreign = directory.appendingPathComponent("BraineeApp-backup-2026-10-20-1630.json")
        try Data("{}".utf8).write(to: foreign)

        for index in 0..<9 {
            try backup.performIfDue(context: container.mainContext, now: start.addingTimeInterval(Double(index) * day))
        }

        #expect(FileManager.default.fileExists(atPath: foreign.path))
        #expect(backup.backupFiles().count == AutoBackup.keepCount)
    }

    // Имя файла содержит время в UTC и читается обратно.
    @Test func имяФайла_читаетсяОбратно() {
        let name = AutoBackup.fileName(for: start)
        #expect(name.hasPrefix("auto-"))
        #expect(AutoBackup.date(fromFileName: name) == start)
        #expect(AutoBackup.date(fromFileName: "pre-swiftdata-20261020-202743") == nil)
    }

    // MARK: - JSON больше не основной

    // Изменение через сервис с побочными эффектами приложения сохраняет хранилище, но не трогает
    // mytasks.json, profile.json и Keychain. Уведомления выключены: их асинхронный пересчёт
    // обратился бы к моделям после освобождения тестового контейнера.
    @Test func изменениеЧерезСервис_неПишетJSONиKeychain() throws {
        let tasksURL = AppDataStore.storageDirectory.appendingPathComponent(AppDataStore.tasksFileName)
        let profileURL = AppDataStore.storageDirectory.appendingPathComponent(AppDataStore.profileFileName)
        let tasksBefore = try? Data(contentsOf: tasksURL)
        let profileBefore = try? Data(contentsOf: profileURL)
        let keychainBefore = KeychainStorage.load(account: AppDataStore.tasksFileName)

        let service = HabitService(
            context: container.mainContext,
            onChange: { AppSideEffects.didChange(in: $0, refreshNotifications: false) }
        )
        let habit = try #require(service.create(title: "Новая привычка"))

        #expect(!container.mainContext.hasChanges)
        #expect(habit.title == "Новая привычка")
        #expect((try? Data(contentsOf: tasksURL)) == tasksBefore)
        #expect((try? Data(contentsOf: profileURL)) == profileBefore)
        #expect(KeychainStorage.load(account: AppDataStore.tasksFileName) == keychainBefore)
    }
}
