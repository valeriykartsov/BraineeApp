//
//  LegacyStorageCleanup.swift
//  BraineeApp
//
//  Удаление устаревшего пути хранения (roadmap SD-6, подтверждено владельцем 2026-10-20):
//  Keychain-копии `mytasks.json` / `profile.json` и файлы в `Documents/BraineeApp/`
//  (включая сохранённые битые `*.corrupt-*.json`). После SD-4 они не обновлялись.
//  Удаляется только если перенос в SwiftData завершён (есть маркер SD-2) — иначе это могла бы быть
//  единственная копия данных. Бэкапы в `Application Support/Backups/` не трогаются.
//  Безопасно запускать на каждом старте: удалять уже нечего — ничего не происходит.

import Foundation

struct LegacyStorageCleanup {
    static let tasksFileName = "mytasks.json"
    static let profileFileName = "profile.json"
    static let legacyKeychainService = "valeravalera.BraineeApp.storage"

    /// `Documents/BraineeApp/` — старая папка с JSON.
    let legacyDirectory: URL
    let keychainService: String
    /// Маркер завершённого переноса JSON → SwiftData (`Application Support/BraineeApp/swiftdata-migration.json`).
    let migrationMarkerURL: URL

    static var standard: LegacyStorageCleanup {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LegacyStorageCleanup(
            legacyDirectory: documents.appendingPathComponent(ModelContainerFactory.folderName, isDirectory: true),
            keychainService: legacyKeychainService,
            migrationMarkerURL: support
                .appendingPathComponent(ModelContainerFactory.folderName, isDirectory: true)
                .appendingPathComponent("swiftdata-migration.json")
        )
    }

    struct Result: Equatable {
        var removedFiles: [String] = []
        var removedKeychainItems: [String] = []
        /// Маркера переноса нет — ничего не удалялось.
        var skippedWithoutMigrationMarker = false
    }

    @discardableResult
    func run() throws -> Result {
        guard FileManager.default.fileExists(atPath: migrationMarkerURL.path) else {
            return Result(skippedWithoutMigrationMarker: true)
        }

        var result = Result()
        for account in [Self.tasksFileName, Self.profileFileName] {
            if try KeychainStorage.delete(account: account, service: keychainService) {
                result.removedKeychainItems.append(account)
            }
        }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: legacyDirectory.path)) ?? []
        for name in names.sorted() where Self.isLegacyFile(name) {
            try FileManager.default.removeItem(at: legacyDirectory.appendingPathComponent(name))
            result.removedFiles.append(name)
        }
        // Папку убираем, только если в ней ничего не осталось (чужие файлы не трогаем).
        if !names.isEmpty, (try? FileManager.default.contentsOfDirectory(atPath: legacyDirectory.path))?.isEmpty == true {
            try FileManager.default.removeItem(at: legacyDirectory)
        }
        return result
    }

    /// `mytasks.json`, `profile.json` и сохранённые битые копии `mytasks.corrupt-*.json` / `profile.corrupt-*.json`.
    static func isLegacyFile(_ name: String) -> Bool {
        if name == tasksFileName || name == profileFileName { return true }
        return name.hasSuffix(".json") && (name.hasPrefix("mytasks.corrupt-") || name.hasPrefix("profile.corrupt-"))
    }
}
