//
//  BackupImport.swift
//  BraineeApp
//
//  Восстановление из резервной копии (roadmap SD-5): ручной экспорт (BASE-2) или автобэкап (SD-4).
//  Порядок: чтение и проверка файла → предпросмотр → подтверждение (во View) → экспорт текущего
//  состояния → замена содержимого хранилища → проверка. Невалидный файл ничего не меняет.
//  Режим только «заменить всё»; слияние — отдельное решение.

import Foundation
import SwiftData

@MainActor
struct BackupRestore {
    /// Проверенный и нормализованный бэкап, готовый к восстановлению.
    struct Preview {
        let document: BackupDocument

        var exportedAt: Date { document.exportedAt }
        var summary: String { document.summary }
    }

    /// Куда перед заменой сохраняется текущее состояние.
    let safetyBackupDirectory: URL
    let defaults: UserDefaults
    let now: () -> Date

    init(
        safetyBackupDirectory: URL = BackupRestore.standardSafetyBackupDirectory,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { .now }
    ) {
        self.safetyBackupDirectory = safetyBackupDirectory
        self.defaults = defaults
        self.now = now
    }

    nonisolated static var standardSafetyBackupDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("pre-restore", isDirectory: true)
    }

    /// Читает файл бэкапа. Не бэкап, более новая версия или битый JSON — ошибка; данные не трогаются.
    static func preview(_ data: Data) throws -> Preview {
        var document = try BackupDocument.decode(from: data)
        document.tasks.normalizeRecords()
        document.profile.normalize()
        return Preview(document: document)
    }

    /// Заменяет данные содержимым бэкапа. Перед заменой сохраняет текущее состояние в файл
    /// и возвращает его адрес. Аватара в бэкапе нет (D-16) — текущий аватар сохраняется.
    /// Тема и акцент из бэкапа записываются в UserDefaults.
    @discardableResult
    func restore(_ preview: Preview, into container: ModelContainer) throws -> URL {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let safetyURL = try exportCurrentState(from: context)

        let tasks = preview.document.tasks
        var profile: ProfileDocument? = preview.document.profile
        if profile?.avatarBase64 == nil {
            let currentAvatar = try context.fetch(FetchDescriptor<UserProfile>()).first?.avatarData
            profile?.avatarBase64 = currentAvatar?.base64EncodedString()
        }

        do {
            _ = try StoreContents.replace(with: tasks, profile: &profile, in: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        try StoreContents.verify(tasks: tasks, profile: profile, in: container)

        defaults.set(preview.document.profile.appThemeRaw, forKey: "appTheme")
        defaults.set(preview.document.profile.accentPaletteRaw, forKey: AccentPalette.storageKey)
        return safetyURL
    }

    /// Текущее состояние в формате обычного бэкапа: `pre-restore-<yyyyMMdd-HHmmss UTC>.json`.
    private func exportCurrentState(from context: ModelContext) throws -> URL {
        let stamp = now()
        try FileManager.default.createDirectory(at: safetyBackupDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var url = safetyBackupDirectory.appendingPathComponent("pre-restore-\(formatter.string(from: stamp)).json")
        if FileManager.default.fileExists(atPath: url.path) {
            url = safetyBackupDirectory.appendingPathComponent(
                "pre-restore-\(formatter.string(from: stamp))-\(UUID().uuidString.prefix(8)).json"
            )
        }
        try BackupDocument.make(from: context, now: stamp).encoded().write(to: url, options: .atomic)
        return url
    }
}
