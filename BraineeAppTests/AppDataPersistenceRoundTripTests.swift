//
//  AppDataPersistenceRoundTripTests.swift
//  BraineeAppTests
//
//  Round-trip JSON → SwiftData → JSON (roadmap BASE-1): то, что импортировано в модели,
//  экспортируется обратно без потерь. Это эталон для будущей миграции на постоянное хранилище.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
struct AppDataPersistenceRoundTripTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    // Импорт документа в SwiftData и экспорт обратно сохраняют все сущности и поля.
    @Test func импортИЭкспортЗадач_безПотерь() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()

        AppDataPersistence.importTasks(original, into: context)
        try context.save()
        let exported = AppDataPersistence.exportTasks(from: context)

        RecordAssert.sameContent(exported, original)
    }

    // Полный путь как в приложении: файл → чтение → SwiftData → экспорт → файл → чтение.
    @Test func полныйПутьЧерезФайл_данныеНеМеняются() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.fullTasksDocument()
        try AppDataStore.saveTasks(original, location: store.location)

        let context = container.mainContext
        AppDataPersistence.importTasks(try AppDataStore.loadTasks(location: store.location), into: context)
        try context.save()
        try AppDataStore.saveTasks(AppDataPersistence.exportTasks(from: context), location: store.location)
        let reloaded = try AppDataStore.loadTasks(location: store.location)

        RecordAssert.sameContent(reloaded, original)
    }

    // Связи и флаги восстанавливаются именно в моделях SwiftData, а не только в JSON.
    @Test func импорт_восстанавливаетСвязиИФлагиВМоделях() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()
        let fullRecord = original.tasks[0]
        let deletedRecord = original.tasks[2]

        AppDataPersistence.importTasks(original, into: context)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        let full = try #require(tasks.first { $0.uuid == fullRecord.id })
        #expect(full.group?.uuid == fullRecord.groupID)
        #expect(Set(full.tags.map(\.uuid)) == Set(fullRecord.tagIDs))
        #expect(full.status == .inProgress)
        #expect(full.priority == .highest)
        #expect(full.reminderOffsets == [.minutes15, .days1])

        let deleted = try #require(tasks.first { $0.uuid == deletedRecord.id })
        #expect(deleted.isSoftDeleted)
        #expect(deleted.deletedAt == deletedRecord.deletedAt)
        #expect(context.fetchActiveTasks().count == 2)

        let habit = try #require(try context.fetch(FetchDescriptor<Habit>()).first)
        #expect(habit.completedDayKeys == ["2026-01-01", "2026-01-03"])
    }

    // Повторный импорт в тот же контекст не создаёт дубликатов: #Unique по uuid
    // превращает вставку в upsert (D-17), связи с группой и тегами сохраняются.
    @Test func повторныйИмпортБезОчистки_неСоздаётДубликатов() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()

        AppDataPersistence.importTasks(original, into: context)
        try context.save()
        AppDataPersistence.importTasks(original, into: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == original.tasks.count)
        #expect(try context.fetchCount(FetchDescriptor<TaskGroup>()) == original.groups.count)
        #expect(try context.fetchCount(FetchDescriptor<TaskTag>()) == original.tags.count)
        #expect(try context.fetchCount(FetchDescriptor<Habit>()) == original.habits.count)
        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: context), original)
    }

    // Повторный импорт профиля с тем же id не создаёт второй профиль.
    @Test func повторныйИмпортПрофиля_неСоздаётДубликата() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.profileDocument()

        AppDataPersistence.importProfile(original, into: context)
        try context.save()
        AppDataPersistence.importProfile(original, into: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    }

    // Профиль: имя, аватар, возраст, пол и дата создания переживают импорт и экспорт.
    // Тема и акцент экспортируются из UserDefaults, поэтому здесь не проверяются.
    @Test func импортИЭкспортПрофиля_безПотерь() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.profileDocument()

        AppDataPersistence.importProfile(original, into: context)
        try context.save()
        let exported = AppDataPersistence.exportProfile(from: context)

        #expect(exported.id == original.id)
        #expect(exported.displayName == original.displayName)
        #expect(exported.avatarBase64 == original.avatarBase64)
        #expect(exported.age == original.age)
        #expect(exported.genderRaw == original.genderRaw)
        #expect(exported.createdAt == original.createdAt)
    }
}
