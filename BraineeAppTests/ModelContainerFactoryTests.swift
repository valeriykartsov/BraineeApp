//
//  ModelContainerFactoryTests.swift
//  BraineeAppTests
//
//  Версионированная схема и фабрика контейнера (roadmap SD-1): persistent-хранилище
//  во временной папке пишет и перечитывает все сущности. Настоящие данные приложения не затрагиваются.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
final class ModelContainerFactoryTests {
    /// Временная папка удаляется целиком вместе с файлами SQLite (-wal, -shm).
    private let directory: URL
    private var storeURL: URL { directory.appendingPathComponent("BraineeApp.store") }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Фикстура

    private let taskID = UUID()
    private let plainTaskID = UUID()
    private let groupID = UUID()
    private let tagAID = UUID()
    private let tagBID = UUID()
    private let habitID = UUID()
    private let profileID = UUID()
    private let avatar = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])

    /// Пишет полный набор сущностей в отдельный контейнер и отпускает его после save().
    private func writeFixture() throws {
        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        let context = ModelContext(container)

        let group = TaskGroup(
            name: "Папка", category: .tasks, sortOrder: 3, uuid: groupID,
            createdAt: PersistenceFixtures.date(100), updatedAt: PersistenceFixtures.date(150)
        )
        let tagA = TaskTag(name: "дом", uuid: tagAID, createdAt: PersistenceFixtures.date(200))
        let tagB = TaskTag(name: "работа", uuid: tagBID, createdAt: PersistenceFixtures.date(210))
        let deadline = PersistenceFixtures.date(5_000)
        let task = TaskItem(
            title: "Готовая задача",
            deadline: deadline,
            hasDeadlineTime: true,
            reminderOffsets: [.atEvent, .minutes15],
            priority: .high,
            category: .tasks,
            status: .done,
            createdAt: PersistenceFixtures.date(300),
            taskDetails: "описание\nв две строки",
            sortOrder: 7,
            uuid: taskID,
            isSoftDeleted: true,
            deletedAt: PersistenceFixtures.date(900),
            updatedAt: PersistenceFixtures.date(800),
            completedAt: PersistenceFixtures.date(700),
            group: group,
            tags: [tagA, tagB]
        )
        let plainTask = TaskItem(title: "Без даты", uuid: plainTaskID)
        let habit = Habit(
            title: "Зарядка", sortOrder: 2, uuid: habitID,
            createdAt: PersistenceFixtures.date(400), updatedAt: PersistenceFixtures.date(450),
            completedDayKeys: ["2026-10-18", "2026-10-20"]
        )
        let profile = UserProfile(
            uuid: profileID, displayName: "Валера", avatarData: avatar,
            age: 30, gender: .male, createdAt: PersistenceFixtures.date(10)
        )

        context.insert(group)
        context.insert(tagA)
        context.insert(tagB)
        context.insert(task)
        context.insert(plainTask)
        context.insert(habit)
        context.insert(profile)
        try context.save()
    }

    private func fetchOne<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> T {
        let all = try context.fetch(FetchDescriptor<T>())
        #expect(all.count == 1)
        return try #require(all.first)
    }

    // MARK: - Тесты

    // Все сущности, их поля и связи переживают закрытие и повторное открытие хранилища.
    @Test func persistentХранилище_перечитываетВсеСущностиИСвязи() throws {
        try writeFixture()

        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        try withExtendedLifetime(container) { () throws in
            let context = ModelContext(container)

            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            #expect(tasks.count == 2)
            let task = try #require(tasks.first { $0.uuid == taskID })
            #expect(task.title == "Готовая задача")
            #expect(task.status == .done)
            #expect(task.isCompleted)
            #expect(task.deadline == PersistenceFixtures.date(5_000))
            #expect(task.hasDeadlineTime)
            #expect(task.reminderOffsets == [.atEvent, .minutes15])
            #expect(task.priority == .high)
            #expect(task.category == .tasks)
            #expect(task.createdAt == PersistenceFixtures.date(300))
            #expect(task.taskDetails == "описание\nв две строки")
            #expect(task.sortOrder == 7)
            #expect(task.isSoftDeleted)
            #expect(task.deletedAt == PersistenceFixtures.date(900))
            #expect(task.updatedAt == PersistenceFixtures.date(800))
            #expect(task.completedAt == PersistenceFixtures.date(700))
            #expect(task.group?.uuid == groupID)
            #expect(Set(task.tags.map(\.uuid)) == [tagAID, tagBID])

            let plainTask = try #require(tasks.first { $0.uuid == plainTaskID })
            #expect(plainTask.group == nil)
            #expect(plainTask.tags.isEmpty)
            #expect(plainTask.deadline == nil)
            #expect(plainTask.completedAt == nil)

            let group = try fetchOne(TaskGroup.self, in: context)
            #expect(group.uuid == groupID)
            #expect(group.name == "Папка")
            #expect(group.sortOrder == 3)
            #expect(group.createdAt == PersistenceFixtures.date(100))
            #expect(group.updatedAt == PersistenceFixtures.date(150))
            #expect(group.tasks?.map(\.uuid) == [taskID])

            let tags = try context.fetch(FetchDescriptor<TaskTag>())
            #expect(Set(tags.map(\.uuid)) == [tagAID, tagBID])
            let tagA = try #require(tags.first { $0.uuid == tagAID })
            #expect(tagA.name == "дом")
            #expect(tagA.createdAt == PersistenceFixtures.date(200))
            #expect(tagA.tasks?.map(\.uuid) == [taskID])

            let habit = try fetchOne(Habit.self, in: context)
            #expect(habit.uuid == habitID)
            #expect(habit.title == "Зарядка")
            #expect(habit.sortOrder == 2)
            #expect(habit.createdAt == PersistenceFixtures.date(400))
            #expect(habit.updatedAt == PersistenceFixtures.date(450))
            #expect(habit.completedDayKeys == ["2026-10-18", "2026-10-20"])

            let profile = try fetchOne(UserProfile.self, in: context)
            #expect(profile.uuid == profileID)
            #expect(profile.displayName == "Валера")
            #expect(profile.avatarData == avatar)
            #expect(profile.age == 30)
            #expect(profile.gender == .male)
            #expect(profile.createdAt == PersistenceFixtures.date(10))
        }
    }

    // Повторное открытие хранилища без изменений не дублирует и не теряет записи.
    @Test func повторноеОткрытие_неМеняетКоличествоЗаписей() throws {
        try writeFixture()

        for _ in 0..<2 {
            let container = try ModelContainerFactory.make(.persistent(url: storeURL))
            try withExtendedLifetime(container) { () throws in
                let context = ModelContext(container)
                #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
                #expect(try context.fetchCount(FetchDescriptor<TaskGroup>()) == 1)
                #expect(try context.fetchCount(FetchDescriptor<TaskTag>()) == 2)
                #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 1)
                #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
            }
        }
    }

    // Хранилище, созданное без версионированной схемы, открывается через план миграций без потерь.
    @Test func хранилищеБезВерсии_открываетсяЧерезПланМиграций() throws {
        let legacyID = UUID()
        do {
            let legacy = try ModelContainer(
                for: TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self, Habit.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            let context = ModelContext(legacy)
            context.insert(TaskItem(title: "Старая", uuid: legacyID))
            try context.save()
        }

        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        try withExtendedLifetime(container) { () throws in
            let tasks = try ModelContext(container).fetch(FetchDescriptor<TaskItem>())
            #expect(tasks.map(\.uuid) == [legacyID])
            #expect(tasks.first?.title == "Старая")
        }
    }

    // В persistent-хранилище вставка записи с существующим uuid обновляет её, а не создаёт дубль,
    // в том числе после повторного открытия файла.
    @Test func persistentХранилище_вставкаСТемЖеUUID_обновляетЗапись() throws {
        try writeFixture()

        let container = try ModelContainerFactory.make(.persistent(url: storeURL))
        try withExtendedLifetime(container) { () throws in
            let context = ModelContext(container)
            context.insert(TaskItem(title: "Новое название", uuid: taskID))
            context.insert(TaskGroup(name: "Другая папка", uuid: groupID))
            context.insert(TaskTag(name: "другой", uuid: tagAID))
            context.insert(Habit(title: "Бег", uuid: habitID))
            context.insert(UserProfile(uuid: profileID, displayName: "Другое имя"))
            try context.save()
        }

        let reopened = try ModelContainerFactory.make(.persistent(url: storeURL))
        try withExtendedLifetime(reopened) { () throws in
            let context = ModelContext(reopened)
            #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
            #expect(try context.fetchCount(FetchDescriptor<TaskGroup>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<TaskTag>()) == 2)
            #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)

            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            #expect(tasks.first { $0.uuid == taskID }?.title == "Новое название")
            #expect(try fetchOne(TaskGroup.self, in: context).name == "Другая папка")
            #expect(try fetchOne(Habit.self, in: context).title == "Бег")
            #expect(try fetchOne(UserProfile.self, in: context).displayName == "Другое имя")
            let tags = try context.fetch(FetchDescriptor<TaskTag>())
            #expect(tags.first { $0.uuid == tagAID }?.name == "другой")
        }
    }

    // Схема V1 содержит ровно пять сущностей с уникальным uuid; имена сущностей — имена классов (важно при заморозке V1).
    @Test func схемаV1_содержитВсеСущности() {
        let names = Set(ModelContainerFactory.schema.entities.map(\.name))
        #expect(names == ["TaskItem", "TaskGroup", "TaskTag", "UserProfile", "Habit"])
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        for entity in ModelContainerFactory.schema.entities {
            #expect(entity.uniquenessConstraints == [["uuid"]], "\(entity.name): uuid должен быть уникальным")
        }
    }
}
