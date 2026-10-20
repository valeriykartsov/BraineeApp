//
//  LegacyStorageCleanupTests.swift
//  BraineeAppTests
//
//  Удаление устаревшего пути хранения (roadmap SD-6): Keychain-копии и JSON в старой папке
//  удаляются только после завершённого переноса; бэкапы и чужие файлы не трогаются;
//  старт приложения не удаляет данные хранилища (R1).
//  Всё во временной папке и отдельном Keychain service.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
final class LegacyStorageCleanupTests {
    private let sandbox: TemporaryDataStore

    init() throws {
        sandbox = try TemporaryDataStore()
    }

    private var legacyDirectory: URL { sandbox.directory.appendingPathComponent("Documents/BraineeApp", isDirectory: true) }
    private var markerURL: URL { sandbox.directory.appendingPathComponent("Support/BraineeApp/swiftdata-migration.json") }
    private var backupsDirectory: URL { sandbox.directory.appendingPathComponent("Support/Backups", isDirectory: true) }

    private var cleanup: LegacyStorageCleanup {
        LegacyStorageCleanup(
            legacyDirectory: legacyDirectory,
            keychainService: sandbox.keychainService,
            migrationMarkerURL: markerURL
        )
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    /// Старое состояние устройства: JSON и битые копии в папке, Keychain-копии, бэкап перед переносом.
    private func makeLegacyState(withMarker: Bool) throws {
        for name in ["mytasks.json", "profile.json", "mytasks.corrupt-20261020-170547.json", "profile.corrupt-20261020-170639.json"] {
            try write("{}", to: legacyDirectory.appendingPathComponent(name))
        }
        try KeychainStorage.save(Data("tasks".utf8), account: "mytasks.json", service: sandbox.keychainService)
        try KeychainStorage.save(Data("profile".utf8), account: "profile.json", service: sandbox.keychainService)
        try write("{}", to: backupsDirectory.appendingPathComponent("pre-swiftdata-20261020-202743/mytasks.json"))
        if withMarker {
            try write("{}", to: markerURL)
        }
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Очистка

    // Перенос завершён: Keychain-записи и все старые JSON (включая битые копии) удаляются, пустая папка тоже.
    @Test func послеПереноса_удаляетKeychainИСтарыеФайлы() throws {
        try makeLegacyState(withMarker: true)

        let result = try cleanup.run()

        #expect(result.removedKeychainItems == ["mytasks.json", "profile.json"])
        #expect(result.removedFiles == [
            "mytasks.corrupt-20261020-170547.json", "mytasks.json",
            "profile.corrupt-20261020-170639.json", "profile.json",
        ])
        #expect(sandbox.keychainData(account: "mytasks.json") == nil)
        #expect(sandbox.keychainData(account: "profile.json") == nil)
        #expect(!exists(legacyDirectory))
    }

    // Бэкапы и маркер переноса остаются на месте.
    @Test func послеПереноса_бэкапыИМаркерОстаются() throws {
        try makeLegacyState(withMarker: true)

        try cleanup.run()

        #expect(exists(backupsDirectory.appendingPathComponent("pre-swiftdata-20261020-202743/mytasks.json")))
        #expect(exists(markerURL))
    }

    // Без маркера переноса ничего не удаляется: это могла бы быть единственная копия данных.
    @Test func безМаркераПереноса_ничегоНеУдаляется() throws {
        try makeLegacyState(withMarker: false)

        let result = try cleanup.run()

        #expect(result.skippedWithoutMigrationMarker)
        #expect(sandbox.keychainData(account: "mytasks.json") == Data("tasks".utf8))
        #expect(exists(legacyDirectory.appendingPathComponent("mytasks.json")))
        #expect(exists(legacyDirectory.appendingPathComponent("mytasks.corrupt-20261020-170547.json")))
    }

    // Посторонние файлы в старой папке не удаляются, и папка остаётся.
    @Test func чужиеФайлы_остаются() throws {
        try makeLegacyState(withMarker: true)
        let foreign = legacyDirectory.appendingPathComponent("notes.txt")
        try write("заметка", to: foreign)

        try cleanup.run()

        #expect(exists(foreign))
        #expect(!exists(legacyDirectory.appendingPathComponent("mytasks.json")))
    }

    // Повторный запуск, когда удалять уже нечего, ничего не делает и не падает.
    @Test func повторныйЗапуск_ничегоНеДелает() throws {
        try makeLegacyState(withMarker: true)
        try cleanup.run()

        let second = try cleanup.run()

        #expect(second == LegacyStorageCleanup.Result())
    }

    // Какие имена считаются старыми файлами.
    @Test func распознаваниеСтарыхФайлов() {
        #expect(LegacyStorageCleanup.isLegacyFile("mytasks.json"))
        #expect(LegacyStorageCleanup.isLegacyFile("profile.json"))
        #expect(LegacyStorageCleanup.isLegacyFile("mytasks.corrupt-20261020-170547-ABCD1234.json"))
        #expect(!LegacyStorageCleanup.isLegacyFile("notes.txt"))
        #expect(!LegacyStorageCleanup.isLegacyFile("BraineeApp-backup-2026-10-20-1630.json"))
        #expect(!LegacyStorageCleanup.isLegacyFile("mytasks.corrupt-x.txt"))
    }

    // MARK: - Старт приложения (R1)

    // Повторные старты не удаляют и не дублируют данные хранилища; очистка старого пути выполняется.
    @Test func старт_неТрогаетДанныеХранилищаИЧиститСтарыйПуть() throws {
        try makeLegacyState(withMarker: true)
        let storeURL = sandbox.directory.appendingPathComponent("Support/BraineeApp/BraineeApp.store")
        let original = PersistenceFixtures.fullTasksDocument()
        let defaultsSuite = "LegacyStorageCleanupTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        defer { UserDefaults().removePersistentDomain(forName: defaultsSuite) }

        let first = try ModelContainerFactory.make(.persistent(url: storeURL))
        AppDataPersistence.importTasks(original, into: first.mainContext)
        try first.mainContext.save()

        for _ in 0..<2 {
            let container = try ModelContainerFactory.make(.persistent(url: storeURL))
            AppDataPersistence.bootstrap(into: container.mainContext, cleanup: cleanup, defaults: defaults)
            RecordAssert.sameContent(AppDataPersistence.exportTasks(from: container.mainContext), original)
        }
        #expect(sandbox.keychainData(account: "mytasks.json") == nil)
        #expect(!exists(legacyDirectory))
        withExtendedLifetime(first) {}
    }
}
