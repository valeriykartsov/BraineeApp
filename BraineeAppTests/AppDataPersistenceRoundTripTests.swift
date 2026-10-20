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

    // Импорт документа в SwiftData и экспорт обратно сохраняют все сущности и поля.
    @Test func импортИЭкспортЗадач_безПотерь() throws {
        // Контейнер держим в переменной: если его освободить, контекст SwiftData падает.
        let container = try TestHelpers.makeContainer()
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

        // Контейнер держим в переменной: если его освободить, контекст SwiftData падает.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        AppDataPersistence.importTasks(try AppDataStore.loadTasks(location: store.location), into: context)
        try context.save()
        try AppDataStore.saveTasks(AppDataPersistence.exportTasks(from: context), location: store.location)
        let reloaded = try AppDataStore.loadTasks(location: store.location)

        RecordAssert.sameContent(reloaded, original)
    }

    // Связи и флаги восстанавливаются именно в моделях SwiftData, а не только в JSON.
    @Test func импорт_восстанавливаетСвязиИФлагиВМоделях() throws {
        // Контейнер держим в переменной: если его освободить, контекст SwiftData падает.
        let container = try TestHelpers.makeContainer()
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

    // ТЕКУЩЕЕ поведение: повторный импорт в тот же контекст создаёт дубликаты.
    // Поэтому bootstrap сначала очищает SwiftData (clearAllData), а будущий мигратор (SD-2)
    // обязан делать upsert по uuid.
    @Test func повторныйИмпортБезОчистки_сейчасСоздаётДубликаты() throws {
        // Контейнер держим в переменной: если его освободить, контекст SwiftData падает.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()

        AppDataPersistence.importTasks(original, into: context)
        AppDataPersistence.importTasks(original, into: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == original.tasks.count * 2)
    }

    // Профиль: имя, аватар, возраст, пол и дата создания переживают импорт и экспорт.
    // Тема и акцент экспортируются из UserDefaults, поэтому здесь не проверяются.
    @Test func импортИЭкспортПрофиля_безПотерь() throws {
        // Контейнер держим в переменной: если его освободить, контекст SwiftData падает.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let original = PersistenceFixtures.profileDocument()

        AppDataPersistence.importProfile(original, into: context)
        try context.save()
        let exported = AppDataPersistence.exportProfile(from: context)

        #expect(exported.displayName == original.displayName)
        #expect(exported.avatarBase64 == original.avatarBase64)
        #expect(exported.age == original.age)
        #expect(exported.genderRaw == original.genderRaw)
        #expect(exported.createdAt == original.createdAt)
    }
}
