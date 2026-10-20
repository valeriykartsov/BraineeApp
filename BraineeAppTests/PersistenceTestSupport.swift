//
//  PersistenceTestSupport.swift
//  BraineeAppTests
//
//  Изолированное хранилище для тестов persistence: временная папка + отдельный Keychain service.
//  Настоящие Documents/BraineeApp и Keychain приложения не затрагиваются.

import Foundation
import Security
import Testing
@testable import BraineeApp

final class TemporaryDataStore {
    let location: AppDataStoreLocation

    init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        location = AppDataStoreLocation(
            directory: directory,
            keychainService: "valeravalera.BraineeApp.tests.\(UUID().uuidString)"
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: location.directory)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: location.keychainService
        ]
        SecItemDelete(query as CFDictionary)
    }

    var tasksFileURL: URL {
        location.directory.appendingPathComponent(AppDataStore.tasksFileName)
    }

    var profileFileURL: URL {
        location.directory.appendingPathComponent(AppDataStore.profileFileName)
    }

    var tasksFileExists: Bool {
        FileManager.default.fileExists(atPath: tasksFileURL.path)
    }

    /// Пишет документ в файл как есть, минуя saveTasks (который перезаписал бы lastSavedAt).
    func writeTasksFile(_ document: MyTasksDocument) throws {
        try PersistenceFixtures.encoder.encode(document).write(to: tasksFileURL, options: .atomic)
    }

    func writeTasksKeychain(_ document: MyTasksDocument) throws {
        let data = try PersistenceFixtures.encoder.encode(document)
        try KeychainStorage.save(data, account: AppDataStore.tasksFileName, service: location.keychainService)
    }

    func writeProfileKeychain(_ document: ProfileDocument) throws {
        let data = try PersistenceFixtures.encoder.encode(document)
        try KeychainStorage.save(data, account: AppDataStore.profileFileName, service: location.keychainService)
    }

    /// Переименованные битые файлы: mytasks.json → mytasks.corrupt-*.json.
    func corruptFiles(of fileName: String) -> [URL] {
        let base = (fileName as NSString).deletingPathExtension
        let names = (try? FileManager.default.contentsOfDirectory(atPath: location.directory.path)) ?? []
        return names
            .filter { $0.hasPrefix("\(base).corrupt-") }
            .sorted()
            .map { location.directory.appendingPathComponent($0) }
    }

    func keychainData(account: String) -> Data? {
        KeychainStorage.load(account: account, service: location.keychainService)
    }
}

/// Тестовые данные. Даты с целыми секундами: ISO 8601 в JSON не хранит доли секунды.
enum PersistenceFixtures {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func date(_ secondsFrom2023: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + secondsFrom2023)
    }

    /// Документ, где заполнены все поля всех сущностей, включая связи и мягкое удаление.
    static func fullTasksDocument(lastSavedAt: Date? = date(1_000)) -> MyTasksDocument {
        let tagWork = TagRecord(id: UUID(), name: "работа", createdAt: date(1))
        let tagHome = TagRecord(id: UUID(), name: "дом", createdAt: date(2))
        let group = GroupRecord(
            id: UUID(),
            name: "Проект",
            categoryRaw: TaskCategory.unifiedRaw,
            sortOrder: 3,
            createdAt: date(3)
        )

        let fullTask = TaskRecord(
            id: UUID(),
            title: "Задача со всеми полями",
            isCompleted: false,
            deadline: date(86_400),
            hasDeadlineTime: true,
            reminderOffsetsRaw: [TaskReminderOffset.minutes15.rawValue, TaskReminderOffset.days1.rawValue],
            priorityRaw: TaskPriority.highest.rawValue,
            categoryRaw: TaskCategory.unifiedRaw,
            statusRaw: TaskStatus.inProgress.rawValue,
            createdAt: date(10),
            taskDetails: "Описание\nв две строки",
            sortOrder: 7,
            groupID: group.id,
            tagIDs: [tagWork.id, tagHome.id]
        )
        let doneTask = TaskRecord(
            id: UUID(),
            title: "Выполненная без даты",
            isCompleted: true,
            deadline: nil,
            priorityRaw: TaskPriority.low.rawValue,
            categoryRaw: TaskCategory.unifiedRaw,
            statusRaw: TaskStatus.done.rawValue,
            createdAt: date(20),
            taskDetails: "",
            sortOrder: 1,
            groupID: nil,
            tagIDs: []
        )
        let deletedTask = TaskRecord(
            id: UUID(),
            title: "В корзине",
            isCompleted: false,
            deadline: date(172_800),
            hasDeadlineTime: false,
            priorityRaw: TaskPriority.medium.rawValue,
            categoryRaw: TaskCategory.unifiedRaw,
            statusRaw: TaskStatus.new.rawValue,
            createdAt: date(30),
            taskDetails: "удалена",
            sortOrder: 2,
            groupID: group.id,
            tagIDs: [tagHome.id],
            isDeleted: true,
            deletedAt: date(40)
        )
        let habit = HabitRecord(
            id: UUID(),
            title: "Спорт",
            sortOrder: 0,
            createdAt: date(50),
            completedDays: ["2026-01-01", "2026-01-03"]
        )

        return MyTasksDocument(
            version: MyTasksDocument.currentVersion,
            lastSavedAt: lastSavedAt,
            tags: [tagWork, tagHome],
            groups: [group],
            tasks: [fullTask, doneTask, deletedTask],
            habits: [habit]
        )
    }

    static func profileDocument() -> ProfileDocument {
        ProfileDocument(
            version: ProfileDocument.currentVersion,
            displayName: "Валера",
            avatarBase64: Data([0x01, 0x02, 0x03, 0xFF]).base64EncodedString(),
            age: 33,
            genderRaw: UserGender.male.rawValue,
            appThemeRaw: AppTheme.dark.rawValue,
            accentPaletteRaw: AccentPalette.blue.rawValue,
            createdAt: date(60)
        )
    }
}

/// Сравнение записей по всем полям. TaskRecord и другие не Equatable, а синтезировать
/// Equatable из тестового модуля нельзя, поэтому сравниваем явно.
/// Порядок tagIDs не проверяется: связи SwiftData не гарантируют порядок (см. round-trip тесты).
enum RecordAssert {
    static func sameTask(_ actual: TaskRecord?, _ expected: TaskRecord, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let actual else {
            Issue.record("Нет задачи \(expected.title)", sourceLocation: sourceLocation)
            return
        }
        #expect(actual.id == expected.id, sourceLocation: sourceLocation)
        #expect(actual.title == expected.title, sourceLocation: sourceLocation)
        #expect(actual.isCompleted == expected.isCompleted, sourceLocation: sourceLocation)
        #expect(actual.deadline == expected.deadline, sourceLocation: sourceLocation)
        #expect(actual.hasDeadlineTime == expected.hasDeadlineTime, sourceLocation: sourceLocation)
        #expect(actual.reminderOffsetsRaw == expected.reminderOffsetsRaw, sourceLocation: sourceLocation)
        #expect(actual.priorityRaw == expected.priorityRaw, sourceLocation: sourceLocation)
        #expect(actual.categoryRaw == expected.categoryRaw, sourceLocation: sourceLocation)
        #expect(actual.statusRaw == expected.statusRaw, sourceLocation: sourceLocation)
        #expect(actual.createdAt == expected.createdAt, sourceLocation: sourceLocation)
        #expect(actual.taskDetails == expected.taskDetails, sourceLocation: sourceLocation)
        #expect(actual.sortOrder == expected.sortOrder, sourceLocation: sourceLocation)
        #expect(actual.groupID == expected.groupID, sourceLocation: sourceLocation)
        #expect(Set(actual.tagIDs) == Set(expected.tagIDs), sourceLocation: sourceLocation)
        #expect(actual.tagIDs.count == expected.tagIDs.count, sourceLocation: sourceLocation)
        #expect(actual.isDeleted == expected.isDeleted, sourceLocation: sourceLocation)
        #expect(actual.deletedAt == expected.deletedAt, sourceLocation: sourceLocation)
    }

    /// Все сущности документа совпадают по id и полям (порядок массивов не важен).
    static func sameContent(_ actual: MyTasksDocument, _ expected: MyTasksDocument, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(actual.tasks.count == expected.tasks.count, sourceLocation: sourceLocation)
        let tasksByID = Dictionary(uniqueKeysWithValues: actual.tasks.map { ($0.id, $0) })
        for task in expected.tasks {
            sameTask(tasksByID[task.id], task, sourceLocation: sourceLocation)
        }

        #expect(actual.groups.count == expected.groups.count, sourceLocation: sourceLocation)
        let groupsByID = Dictionary(uniqueKeysWithValues: actual.groups.map { ($0.id, $0) })
        for group in expected.groups {
            let found = groupsByID[group.id]
            #expect(found?.name == group.name, sourceLocation: sourceLocation)
            #expect(found?.categoryRaw == group.categoryRaw, sourceLocation: sourceLocation)
            #expect(found?.sortOrder == group.sortOrder, sourceLocation: sourceLocation)
            #expect(found?.createdAt == group.createdAt, sourceLocation: sourceLocation)
        }

        #expect(actual.tags.count == expected.tags.count, sourceLocation: sourceLocation)
        let tagsByID = Dictionary(uniqueKeysWithValues: actual.tags.map { ($0.id, $0) })
        for tag in expected.tags {
            #expect(tagsByID[tag.id]?.name == tag.name, sourceLocation: sourceLocation)
            #expect(tagsByID[tag.id]?.createdAt == tag.createdAt, sourceLocation: sourceLocation)
        }

        #expect(actual.habits.count == expected.habits.count, sourceLocation: sourceLocation)
        let habitsByID = Dictionary(uniqueKeysWithValues: actual.habits.map { ($0.id, $0) })
        for habit in expected.habits {
            let found = habitsByID[habit.id]
            #expect(found?.title == habit.title, sourceLocation: sourceLocation)
            #expect(found?.sortOrder == habit.sortOrder, sourceLocation: sourceLocation)
            #expect(found?.createdAt == habit.createdAt, sourceLocation: sourceLocation)
            #expect(found?.completedDays == habit.completedDays, sourceLocation: sourceLocation)
        }
    }
}
