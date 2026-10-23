//
//  StoreContents.swift
//  BraineeApp
//
//  Замена содержимого хранилища SwiftData JSON-документом и сверка результата.
//  Используется восстановлением из бэкапа (SD-5); раньше также переносом JSON при первом запуске (SD-2).

import Foundation
import SwiftData

@MainActor
enum StoreContents {
    /// Данные в хранилище не совпали с документом.
    struct VerificationError: LocalizedError {
        var problems: [String]

        var errorDescription: String? {
            "Данные в хранилище не совпали с исходными (\(problems.count)): "
                + problems.prefix(5).joined(separator: "; ")
        }
    }

    /// Приводит хранилище к документу: записи с теми же uuid обновляются (`#Unique`), новые добавляются,
    /// записей, которых нет в документе, не остаётся. Не сохраняет — это делает вызывающий.
    /// Профиль без id получает uuid текущего профиля в хранилище, иначе новый (поэтому `inout`).
    /// - Returns: сколько записей удалено.
    static func replace(with tasks: MyTasksDocument, profile: inout ProfileDocument?, in context: ModelContext) throws -> Int {
        if profile != nil, profile?.id == nil {
            profile?.id = try context.fetch(FetchDescriptor<UserProfile>()).first?.uuid ?? UUID()
        }
        let removed = try removeStaleRecords(keeping: tasks, profileID: profile?.id, in: context)
        AppDataPersistence.importTasks(tasks, into: context)
        if let profile {
            AppDataPersistence.importProfile(profile, into: context)
        }
        return removed
    }

    /// Удаляет из хранилища записи, которых нет в документе.
    private static func removeStaleRecords(keeping document: MyTasksDocument, profileID: UUID?, in context: ModelContext) throws -> Int {
        // Подзадачи — первыми: подзадачи удаляемых задач тоже не в документе, каскад их не посчитает дважды.
        try removeRecords(TaskSubtask.self, notIn: Set(document.tasks.flatMap(\.subtasks).map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(TaskItem.self, notIn: Set(document.tasks.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(TaskGroup.self, notIn: Set(document.groups.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(TaskTag.self, notIn: Set(document.tags.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(Habit.self, notIn: Set(document.habits.map(\.id)), uuid: \.uuid, in: context)
            + removeRecords(UserProfile.self, notIn: Set([profileID].compactMap { $0 }), uuid: \.uuid, in: context)
    }

    private static func removeRecords<T: PersistentModel>(
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

    /// Читает хранилище новым контекстом и сверяет каждую запись по uuid со всеми полями документа.
    /// Лишние и недостающие записи — тоже ошибка.
    static func verify(tasks expected: MyTasksDocument, profile: ProfileDocument?, in container: ModelContainer) throws {
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
            throw VerificationError(problems: problems)
        }
    }

    /// Порядок тегов и подзадач в связях SwiftData не гарантирован — сравниваем отсортированными.
    private static func canonical(_ record: TaskRecord) -> TaskRecord {
        var copy = record
        copy.tagIDs.sort { $0.uuidString < $1.uuidString }
        copy.subtasks.sort { $0.id.uuidString < $1.id.uuidString }
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
}
