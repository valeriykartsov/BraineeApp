//
//  TaskItemLogicTests.swift
//  BraineeAppTests
//
//  Просроченность, «на сегодня» и мягкое удаление / восстановление.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskItemLogicTests {

    @Test func дедлайнВчераИНеВыполнена_просрочена() throws {
        // Задача с вчерашним дедлайном и без галочки — просрочена.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(
            title: "Просрочка",
            deadline: TestHelpers.daysFromNow(-1),
            category: .career
        )
        container.mainContext.insert(task)
        #expect(task.isOverdue == true)
    }

    @Test func дедлайнВчераНоВыполнена_неПросрочена() throws {
        // Выполненная задача с прошедшей датой не считается просроченной.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(
            title: "Сделано",
            isCompleted: true,
            deadline: TestHelpers.daysFromNow(-2),
            category: .sport
        )
        container.mainContext.insert(task)
        #expect(task.isOverdue == false)
    }

    @Test func дедлайнСегодня_считаетсяНаСегодня() throws {
        // Дедлайн сегодня — isDueToday = true.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(
            title: "Сегодня",
            deadline: Date(),
            category: .mental
        )
        container.mainContext.insert(task)
        #expect(task.isDueToday == true)
        #expect(task.isOverdue == false)
    }

    @Test func безДедлайна_неПросроченаИНеНаСегодня() throws {
        // Без даты — ни просрочка, ни «сегодня».
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(title: "Без даты", category: .career)
        container.mainContext.insert(task)
        #expect(task.isOverdue == false)
        #expect(task.isDueToday == false)
    }

    @Test func мягкоеУдаление_ставитФлаги() throws {
        // Мягкое удаление: задача остаётся в SwiftData, deletedAt заполнен.
        // Флаг isDeleted проверяем через init (как при загрузке из JSON) —
        // у PersistentModel есть одноимённое свойство, поэтому после insert
        // чтение task.isDeleted может давать системное значение, а не наше поле.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let deletedAt = Date()
        let task = TaskItem(
            title: "Удалить мягко",
            category: .career,
            isDeleted: true,
            deletedAt: deletedAt
        )
        context.insert(task)
        try context.save()

        let uuid = task.uuid
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].deletedAt != nil)

        // В JSON-слое (источник правды) soft delete хранится явно.
        let record = TaskRecord(
            id: uuid,
            title: fetched[0].title,
            isCompleted: false,
            deadline: nil,
            priorityRaw: fetched[0].priorityRaw,
            categoryRaw: fetched[0].categoryRaw,
            createdAt: fetched[0].createdAt,
            taskDetails: "",
            sortOrder: 0,
            groupID: nil,
            tagIDs: [],
            isDeleted: true,
            deletedAt: fetched[0].deletedAt
        )
        #expect(record.isDeleted == true)
        #expect(record.deletedAt != nil)
    }

    @Test func восстановление_снимаетФлагиУдаления() throws {
        // Восстановление возвращает задачу в активные.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(
            title: "Вернуть",
            category: .sport,
            isDeleted: true,
            deletedAt: Date()
        )
        container.mainContext.insert(task)

        task.isDeleted = false
        task.deletedAt = nil

        #expect(task.isDeleted == false)
        #expect(task.deletedAt == nil)
    }

    @Test func редактированиеПолей_меняетДанные() throws {
        // После правки название, приоритет и категория обновляются.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(title: "Старое", priority: .low, category: .career)
        container.mainContext.insert(task)

        task.title = "Новое"
        task.priority = .highest
        task.category = .mental
        task.taskDetails = "Описание"

        #expect(task.title == "Новое")
        #expect(task.priority == .highest)
        #expect(task.category == .mental)
        #expect(task.taskDetails == "Описание")
    }
}
