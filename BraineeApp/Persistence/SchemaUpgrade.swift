//
//  SchemaUpgrade.swift
//  BraineeApp
//
//  Защищённый переход хранилища с SchemaV1 на SchemaV2 при старте (D-39):
//  бэкап → копирование → проверка → маркер → переключение.
//  1. Есть маркер — хранилище уже на V2, просто открываем.
//  2. Хранилища нет (новая установка) — переводить нечего: открываем и ставим маркер.
//  3. Иначе: копия файлов SQLite и полная выгрузка данных схемой V1 (только чтение) в
//     `Backups/pre-schema-v2/` → открытие схемой V2 (лёгкая миграция SwiftData) → сверка каждой записи
//     с выгрузкой → маркер. Сбой — ошибка (экран ошибки), маркер не пишется.
//  Повтор после сбоя не создаёт второй бэкап: сверка идёт с уже сохранённым, даже если хранилище успело стать V2.
//  Бэкапы и хранилище здесь не удаляются и не перезаписываются.

import Foundation
import SwiftData

@MainActor
struct SchemaUpgrade {
    let storeURL: URL
    /// Папка бэкапа перед переходом: копии файлов хранилища, `backup.json`, `contents.json`.
    let backupDirectory: URL
    let markerURL: URL
    var defaults: UserDefaults = .standard

    static var standard: SchemaUpgrade {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SchemaUpgrade(
            storeURL: ModelContainerFactory.standardStoreURL,
            backupDirectory: support
                .appendingPathComponent("Backups", isDirectory: true)
                .appendingPathComponent("pre-schema-v2", isDirectory: true),
            markerURL: support
                .appendingPathComponent(ModelContainerFactory.folderName, isDirectory: true)
                .appendingPathComponent("schema-v2-migration.json")
        )
    }

    /// Бэкап в формате ручного экспорта (D-16): его можно восстановить в «Профиль → Хранение данных».
    /// В отличие от ручного экспорта, аватар сохраняется — это полный снимок перед миграцией.
    static let backupFileName = "backup.json"
    /// Тот же снимок с точными датами (в `backup.json` даты округлены до секунды) — для сверки.
    static let contentsFileName = "contents.json"

    struct Marker: Codable, Equatable {
        var schemaVersion: String
        var migratedAt: Date
        /// nil — новая установка, переводить было нечего.
        var backupFolder: String?
        var tasks: Int
        var groups: Int
        var tags: Int
        var habits: Int
        var hasProfile: Bool
    }

    /// Точный снимок хранилища V1.
    struct Contents: Codable {
        var tasks: MyTasksDocument
        var profile: ProfileDocument?
    }

    enum UpgradeError: LocalizedError {
        case copyMismatch(String)
        case unexpectedBackupFolder

        var errorDescription: String? {
            switch self {
            case .copyMismatch(let name):
                "Копия файла хранилища \(name) не совпала с оригиналом."
            case .unexpectedBackupFolder:
                "Папка Backups/pre-schema-v2 есть, но бэкапа в ней нет — переход на новую схему остановлен."
            }
        }
    }

    // MARK: - Открытие хранилища

    func openStore(now: Date = .now) throws -> ModelContainer {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: markerURL.path) {
            return try ModelContainerFactory.make(.persistent(url: storeURL))
        }

        guard fileManager.fileExists(atPath: storeURL.path) else {
            let container = try ModelContainerFactory.make(.persistent(url: storeURL))
            try writeMarker(contents: nil, now: now)
            return container
        }

        let contents = try savedContents() ?? makeBackup(now: now)
        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        try StoreContents.verify(tasks: contents.tasks, profile: contents.profile, in: container)
        try writeMarker(contents: contents, now: now)
        return container
    }

    // MARK: - Бэкап

    /// Снимок из бэкапа прошлой попытки; nil — бэкапа ещё нет.
    private func savedContents() throws -> Contents? {
        let contentsURL = backupDirectory.appendingPathComponent(Self.contentsFileName)
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return nil }
        guard FileManager.default.fileExists(atPath: contentsURL.path) else { throw UpgradeError.unexpectedBackupFolder }
        return try JSONDecoder().decode(Contents.self, from: Data(contentsOf: contentsURL))
    }

    /// Собирает бэкап во временной папке `pre-schema-v2.partial` и переименовывает её только целиком готовой.
    private func makeBackup(now: Date) throws -> Contents {
        let fileManager = FileManager.default
        let partial = backupDirectory.deletingLastPathComponent()
            .appendingPathComponent(backupDirectory.lastPathComponent + ".partial", isDirectory: true)
        // Остаток прерванной попытки — наша же незавершённая копия, не бэкап.
        if fileManager.fileExists(atPath: partial.path) {
            try fileManager.removeItem(at: partial)
        }
        try fileManager.createDirectory(at: partial, withIntermediateDirectories: true)

        // Файлы SQLite копируются до открытия хранилища — так копия согласована.
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let copy = partial.appendingPathComponent(source.lastPathComponent)
            try fileManager.copyItem(at: source, to: copy)
            guard try Data(contentsOf: source) == Data(contentsOf: copy) else {
                throw UpgradeError.copyMismatch(source.lastPathComponent)
            }
        }

        let contents = try readV1Contents()

        let backup = BackupDocument(
            format: BackupDocument.formatID,
            version: BackupDocument.currentVersion,
            exportedAt: now,
            tasks: contents.tasks,
            profile: contents.profile ?? .empty
        )
        try backup.encoded().write(to: partial.appendingPathComponent(Self.backupFileName), options: .atomic)
        _ = try BackupDocument.decode(from: Data(contentsOf: partial.appendingPathComponent(Self.backupFileName)))

        let contentsURL = partial.appendingPathComponent(Self.contentsFileName)
        try JSONEncoder().encode(contents).write(to: contentsURL, options: .atomic)
        _ = try JSONDecoder().decode(Contents.self, from: Data(contentsOf: contentsURL))

        try fileManager.moveItem(at: partial, to: backupDirectory)
        return contents
    }

    /// Читает хранилище схемой V1 без права записи. Сопоставление полей — как в `AppDataPersistence.exportTasks`,
    /// без нормализации: снимок должен совпасть с тем, что после миграции выгрузит V2.
    private func readV1Contents() throws -> Contents {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return try withExtendedLifetime(container) {
            let context = ModelContext(container)
            let tags = try context.fetch(FetchDescriptor<SchemaV1.TaskTag>())
            let groups = try context.fetch(FetchDescriptor<SchemaV1.TaskGroup>())
            let tasks = try context.fetch(FetchDescriptor<SchemaV1.TaskItem>())
            let habits = try context.fetch(FetchDescriptor<SchemaV1.Habit>())
            let profile = try context.fetch(FetchDescriptor<SchemaV1.UserProfile>()).first

            let document = MyTasksDocument(
                version: MyTasksDocument.currentVersion,
                lastSavedAt: nil,
                tags: tags.map {
                    TagRecord(id: $0.uuid, name: $0.name, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
                },
                groups: groups.map {
                    GroupRecord(
                        id: $0.uuid,
                        name: $0.name,
                        categoryRaw: $0.categoryRaw,
                        sortOrder: $0.sortOrder,
                        createdAt: $0.createdAt,
                        updatedAt: $0.updatedAt
                    )
                },
                tasks: tasks.map {
                    TaskRecord(
                        id: $0.uuid,
                        title: $0.title,
                        isCompleted: $0.isCompleted,
                        deadline: $0.deadline,
                        hasDeadlineTime: $0.hasDeadlineTime,
                        reminderOffsetsRaw: $0.reminderOffsetsRaw,
                        priorityRaw: $0.priorityRaw,
                        categoryRaw: $0.categoryRaw,
                        statusRaw: $0.statusRaw,
                        createdAt: $0.createdAt,
                        taskDetails: $0.taskDetails,
                        sortOrder: $0.sortOrder,
                        groupID: $0.group?.uuid,
                        tagIDs: $0.tags.map(\.uuid),
                        isDeleted: $0.isSoftDeleted,
                        deletedAt: $0.isSoftDeleted ? ($0.deletedAt ?? $0.updatedAt) : nil,
                        updatedAt: $0.updatedAt,
                        completedAt: $0.completedAt
                    )
                },
                habits: habits.map {
                    HabitRecord(
                        id: $0.uuid,
                        title: $0.title,
                        sortOrder: $0.sortOrder,
                        createdAt: $0.createdAt,
                        completedDays: (try? JSONDecoder().decode([String].self, from: Data($0.completedDaysRaw.utf8))) ?? [],
                        updatedAt: $0.updatedAt
                    )
                }
            )

            let profileDocument = profile.map {
                ProfileDocument(
                    version: ProfileDocument.currentVersion,
                    id: $0.uuid,
                    displayName: $0.displayName,
                    avatarBase64: $0.avatarData?.base64EncodedString(),
                    age: $0.age,
                    genderRaw: $0.genderRaw,
                    appThemeRaw: defaults.string(forKey: "appTheme") ?? AppTheme.system.rawValue,
                    accentPaletteRaw: defaults.string(forKey: AccentPalette.storageKey) ?? AccentPalette.orange.rawValue,
                    createdAt: $0.createdAt
                )
            }
            return Contents(tasks: document, profile: profileDocument)
        }
    }

    // MARK: - Маркер

    private func writeMarker(contents: Contents?, now: Date) throws {
        let marker = Marker(
            schemaVersion: "\(SchemaV2.versionIdentifier)",
            migratedAt: now,
            backupFolder: contents == nil ? nil : "Backups/\(backupDirectory.lastPathComponent)",
            tasks: contents?.tasks.tasks.count ?? 0,
            groups: contents?.tasks.groups.count ?? 0,
            tags: contents?.tasks.tags.count ?? 0,
            habits: contents?.tasks.habits.count ?? 0,
            hasProfile: contents?.profile != nil
        )
        try FileManager.default.createDirectory(at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(marker).write(to: markerURL, options: .atomic)
    }
}
