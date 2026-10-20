//
//  JSONToSwiftDataMigrator.swift
//  BraineeApp
//
//  Перенос данных из JSON (mytasks.json, profile.json) в постоянное хранилище SwiftData (roadmap SD-2).
//  Пока не подключён к старту приложения — это SD-3.
//  Порядок: бэкап → копирование (upsert по uuid) → проверка каждой записи → маркер.
//  Исходные файлы и Keychain только читаются; маркер ставится только после успешной проверки.

import Foundation
import SwiftData

/// Итог миграции: сколько записей перенесено и что отбросила или исправила нормализация (риск R3).
struct MigrationReport: Codable, Equatable {
    struct Counts: Codable, Equatable {
        var tasks = 0
        var groups = 0
        var tags = 0
        var habits = 0
        var profiles = 0
    }

    var migratedAt: Date
    /// Папка бэкапа внутри `Application Support/Backups/`.
    var backupFolderName: String
    /// Записей в исходных данных до нормализации.
    var source: Counts
    /// Записей в хранилище после миграции.
    var migrated: Counts
    /// Повторы uuid, отброшенные нормализацией (остаётся первая запись).
    var droppedDuplicates: Counts
    /// Привычки сверх лимита `Habit.maxCount` (по sortOrder).
    var droppedHabitsOverLimit = 0
    /// Привычки с пустым названием.
    var droppedHabitsWithEmptyTitle = 0
    /// Ссылки задач на несуществующую группу — убраны, задачи сохранены.
    var clearedGroupReferences = 0
    /// Ссылки задач на несуществующие теги — убраны, задачи сохранены.
    var removedTagReferences = 0
    /// Записи хранилища, которых нет в JSON (остатки прерванной попытки), — удалены.
    var removedStaleRecords = 0

    /// Сколько записей из JSON не попало в хранилище.
    var droppedRecords: Int {
        droppedDuplicates.tasks + droppedDuplicates.groups + droppedDuplicates.tags + droppedDuplicates.habits
            + droppedHabitsOverLimit + droppedHabitsWithEmptyTitle
    }
}

enum MigrationError: LocalizedError {
    case backupFailed(String)
    /// Данные в хранилище не совпали с JSON; маркер не поставлен.
    case verificationFailed([String])

    var errorDescription: String? {
        switch self {
        case .backupFailed(let reason):
            "Не удалось сделать резервную копию перед переносом данных: \(reason)"
        case .verificationFailed(let problems):
            "Перенесённые данные не совпали с исходными (\(problems.count)): "
                + problems.prefix(5).joined(separator: "; ")
        }
    }
}

@MainActor
struct JSONToSwiftDataMigrator {
    struct Locations {
        /// Откуда читать JSON и Keychain-копии.
        var source: AppDataStoreLocation
        /// Куда класть `pre-swiftdata-<дата>/`.
        var backupsDirectory: URL
        /// Файл-маркер завершённой миграции (внутри — отчёт).
        var markerURL: URL

        static var standard: Locations {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            return Locations(
                source: .standard,
                backupsDirectory: support.appendingPathComponent("Backups", isDirectory: true),
                markerURL: support
                    .appendingPathComponent(AppDataStore.folderName, isDirectory: true)
                    .appendingPathComponent("swiftdata-migration.json")
            )
        }
    }

    /// Точки, после которых тесты могут имитировать сбой.
    enum Stage {
        case backupCreated
        case saved
    }

    enum Outcome: Equatable {
        /// Маркер уже есть — ничего не делали. Отчёт nil, если маркер не читается.
        case alreadyCompleted(MigrationReport?)
        case migrated(MigrationReport)
    }

    /// Содержимое файла-маркера.
    private struct Marker: Codable {
        var formatVersion = 1
        var schemaVersion: String
        var report: MigrationReport
    }

    let locations: Locations
    private let now: () -> Date
    private let checkpoint: (Stage) throws -> Void

    init(
        locations: Locations = .standard,
        now: @escaping () -> Date = { .now },
        checkpoint: @escaping (Stage) throws -> Void = { _ in }
    ) {
        self.locations = locations
        self.now = now
        self.checkpoint = checkpoint
    }

    var isCompleted: Bool {
        FileManager.default.fileExists(atPath: locations.markerURL.path)
    }

    /// Переносит данные в `container`. Повторный запуск после успеха ничего не делает;
    /// после сбоя — переносит заново без дублей (upsert по uuid, `#Unique`).
    @discardableResult
    func run(into container: ModelContainer) throws -> Outcome {
        if isCompleted {
            return .alreadyCompleted(readMarker()?.report)
        }

        let rawTasks = try AppDataStore.readTasksSource(location: locations.source) ?? .empty
        let rawProfile = try AppDataStore.readProfileSource(location: locations.source)

        let backupFolderName = try makeBackup()
        try checkpoint(.backupCreated)

        var tasks = rawTasks
        tasks.normalizeRecords()
        var profile = rawProfile.map { document -> ProfileDocument in
            var normalized = document
            normalized.normalize()
            return normalized
        }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        let removedStale: Int
        do {
            // Старый profile.json без id: берём uuid профиля из прерванной попытки, иначе новый.
            if profile != nil, profile?.id == nil {
                profile?.id = try context.fetch(FetchDescriptor<UserProfile>()).first?.uuid ?? UUID()
            }
            removedStale = try removeStaleRecords(keeping: tasks, profileID: profile?.id, in: context)
            AppDataPersistence.importTasks(tasks, into: context)
            if let profile {
                AppDataPersistence.importProfile(profile, into: context)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        try checkpoint(.saved)

        try verify(tasks: tasks, profile: profile, in: container)

        var report = Self.normalizationReport(raw: rawTasks, normalized: tasks)
        report.migratedAt = now()
        report.backupFolderName = backupFolderName
        report.source.profiles = rawProfile == nil ? 0 : 1
        report.migrated.profiles = profile == nil ? 0 : 1
        report.removedStaleRecords = removedStale

        let version = CurrentSchema.versionIdentifier
        try writeMarker(Marker(schemaVersion: "\(version.major).\(version.minor).\(version.patch)", report: report))
        return .migrated(report)
    }

    // MARK: - Отчёт

    /// Сравнивает исходный документ с нормализованным. Порядок шагов — как в `normalizeRecords()`.
    static func normalizationReport(raw: MyTasksDocument, normalized: MyTasksDocument) -> MigrationReport {
        let uniqueHabits = Set(raw.habits.map(\.id)).count
        let habitsWithinLimit = min(uniqueHabits, Habit.maxCount)

        let validGroupIDs = Set(raw.groups.map(\.id))
        let validTagIDs = Set(raw.tags.map(\.id))
        var seenTaskIDs = Set<UUID>()
        var clearedGroupReferences = 0
        var removedTagReferences = 0
        for task in raw.tasks where seenTaskIDs.insert(task.id).inserted {
            if let groupID = task.groupID, !validGroupIDs.contains(groupID) {
                clearedGroupReferences += 1
            }
            removedTagReferences += task.tagIDs.filter { !validTagIDs.contains($0) }.count
        }

        return MigrationReport(
            migratedAt: .now,
            backupFolderName: "",
            source: MigrationReport.Counts(
                tasks: raw.tasks.count,
                groups: raw.groups.count,
                tags: raw.tags.count,
                habits: raw.habits.count
            ),
            migrated: MigrationReport.Counts(
                tasks: normalized.tasks.count,
                groups: normalized.groups.count,
                tags: normalized.tags.count,
                habits: normalized.habits.count
            ),
            droppedDuplicates: MigrationReport.Counts(
                tasks: raw.tasks.count - Set(raw.tasks.map(\.id)).count,
                groups: raw.groups.count - validGroupIDs.count,
                tags: raw.tags.count - validTagIDs.count,
                habits: raw.habits.count - uniqueHabits
            ),
            droppedHabitsOverLimit: uniqueHabits - habitsWithinLimit,
            droppedHabitsWithEmptyTitle: habitsWithinLimit - normalized.habits.count,
            clearedGroupReferences: clearedGroupReferences,
            removedTagReferences: removedTagReferences
        )
    }

    // MARK: - Бэкап

    /// Копирует исходные файлы и Keychain-копии в `Backups/pre-swiftdata-<дата>/` и сверяет копии побайтно.
    private func makeBackup() throws -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var folderName = "pre-swiftdata-\(formatter.string(from: now()))"
        if FileManager.default.fileExists(atPath: locations.backupsDirectory.appendingPathComponent(folderName).path) {
            folderName += "-\(UUID().uuidString.prefix(8))"
        }
        let folder = locations.backupsDirectory.appendingPathComponent(folderName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for fileName in [AppDataStore.tasksFileName, AppDataStore.profileFileName] {
                let source = locations.source.directory.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: source.path) {
                    try copyVerified(Data(contentsOf: source), to: folder.appendingPathComponent(fileName))
                }
                if let keychainData = KeychainStorage.load(account: fileName, service: locations.source.keychainService) {
                    try copyVerified(keychainData, to: folder.appendingPathComponent("keychain-\(fileName)"))
                }
            }
        } catch {
            throw MigrationError.backupFailed(error.localizedDescription)
        }
        return folderName
    }

    private func copyVerified(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw MigrationError.backupFailed("копия \(url.lastPathComponent) не совпала с оригиналом")
        }
    }

    // MARK: - Копирование

    /// Удаляет из хранилища записи, которых нет в JSON (остались от прерванной попытки).
    private func removeStaleRecords(keeping document: MyTasksDocument, profileID: UUID?, in context: ModelContext) throws -> Int {
        try removeRecords(TaskItem.self, notIn: Set(document.tasks.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(TaskGroup.self, notIn: Set(document.groups.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(TaskTag.self, notIn: Set(document.tags.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(Habit.self, notIn: Set(document.habits.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(UserProfile.self, notIn: Set([profileID].compactMap { $0 }), uuid: \.uuid, in: context)
    }

    private func removeRecords<T: PersistentModel>(
        _ type: T.Type,
        notIn ids: Set<UUID>,
        uuid: KeyPath<T, UUID>,
        in context: ModelContext
    ) throws -> Int {
        let stale = try context.fetch(FetchDescriptor<T>()).filter { !ids.contains($0[keyPath: uuid]) }
        stale.forEach { context.delete($0) }
        return stale.count
    }

    // MARK: - Проверка

    /// Читает хранилище новым контекстом и сверяет каждую запись по uuid со всеми полями JSON.
    private func verify(tasks expected: MyTasksDocument, profile: ProfileDocument?, in container: ModelContainer) throws {
        let context = ModelContext(container)
        let actual = AppDataPersistence.exportTasks(from: context)

        var problems: [String] = []
        problems += Self.compare("задача", expected: expected.tasks.map(Self.canonical), actual: actual.tasks.map(Self.canonical))
        problems += Self.compare("папка", expected: expected.groups, actual: actual.groups)
        problems += Self.compare("тег", expected: expected.tags, actual: actual.tags)
        problems += Self.compare("привычка", expected: expected.habits, actual: actual.habits)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        if let profile {
            if profiles.count != 1 {
                problems.append("профилей в хранилище: \(profiles.count), ожидался 1")
            } else if let stored = profiles.first {
                let storedAvatar = stored.avatarData?.base64EncodedString()
                let expectedAvatar = profile.avatarBase64.flatMap { Data(base64Encoded: $0) }?.base64EncodedString()
                if stored.uuid != profile.id
                    || stored.displayName != profile.displayName
                    || storedAvatar != expectedAvatar
                    || stored.age != profile.age
                    || stored.genderRaw != profile.genderRaw
                    || stored.createdAt != profile.createdAt {
                    problems.append("профиль \(stored.uuid): поля не совпадают")
                }
            }
        } else if !profiles.isEmpty {
            problems.append("в хранилище \(profiles.count) профиль(ей), в JSON профиля нет")
        }

        if !problems.isEmpty {
            throw MigrationError.verificationFailed(problems)
        }
    }

    /// Порядок тегов в связях SwiftData не гарантирован — сравниваем отсортированными.
    private static func canonical(_ record: TaskRecord) -> TaskRecord {
        var copy = record
        copy.tagIDs.sort { $0.uuidString < $1.uuidString }
        return copy
    }

    /// Сравнивает записи по uuid через JSON-представление (все поля, даты без округления).
    private static func compare<T: Encodable & Identifiable>(
        _ kind: String,
        expected: [T],
        actual: [T]
    ) -> [String] where T.ID == UUID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .deferredToDate

        func encoded(_ records: [T]) -> [UUID: Data] {
            Dictionary(records.map { ($0.id, (try? encoder.encode($0)) ?? Data()) }, uniquingKeysWith: { first, _ in first })
        }
        let expectedByID = encoded(expected)
        let actualByID = encoded(actual)

        var problems: [String] = []
        if actualByID.count != actual.count {
            problems.append("\(kind): в хранилище повторяются uuid")
        }
        for (id, data) in expectedByID {
            guard let stored = actualByID[id] else {
                problems.append("\(kind) \(id): нет в хранилище")
                continue
            }
            if stored != data {
                problems.append("\(kind) \(id): поля не совпадают")
            }
        }
        for id in actualByID.keys where expectedByID[id] == nil {
            problems.append("\(kind) \(id): лишняя запись в хранилище")
        }
        return problems
    }

    // MARK: - Маркер

    private static let markerEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private func writeMarker(_ marker: Marker) throws {
        try FileManager.default.createDirectory(
            at: locations.markerURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.markerEncoder.encode(marker).write(to: locations.markerURL, options: .atomic)
    }

    private func readMarker() -> Marker? {
        guard let data = try? Data(contentsOf: locations.markerURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Marker.self, from: data)
    }
}
