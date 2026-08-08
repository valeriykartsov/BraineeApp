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
            category: .tasks
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
            category: .tasks
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
            category: .tasks
        )
        container.mainContext.insert(task)
        #expect(task.isDueToday == true)
        #expect(task.isOverdue == false)
    }

    @Test func безДедлайна_неПросроченаИНеНаСегодня() throws {
        // Без даты — ни просрочка, ни «сегодня».
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(title: "Без даты", category: .tasks)
        container.mainContext.insert(task)
        #expect(task.isOverdue == false)
        #expect(task.isDueToday == false)
    }

    @Test func мягкоеУдалениеПослеПрисвоения_сохраняетсяВМоделиИJSONФлаге() throws {
        // Регрессия: поле нельзя называть isDeleted (конфликт со SwiftData) —
        // иначе после перезапуска удалённая задача снова появлялась в разделе.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let task = TaskItem(title: "Удалить мягко", category: .tasks)
        context.insert(task)

        task.isSoftDeleted = true
        task.deletedAt = Date()
        try context.save()

        #expect(task.isSoftDeleted == true)
        #expect(task.deletedAt != nil)

        let uuid = task.uuid
        let fetched = try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == uuid })
        )
        #expect(fetched.count == 1)
        #expect(fetched[0].isSoftDeleted == true)
        #expect(fetched[0].deletedAt != nil)

        // Как при export в mytasks.json: isSoftDeleted → record.isDeleted.
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
            isDeleted: fetched[0].isSoftDeleted,
            deletedAt: fetched[0].deletedAt
        )
        #expect(record.isDeleted == true)
    }

    @Test func восстановление_снимаетФлагиУдаления() throws {
        // Восстановление возвращает задачу в активные.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(
            title: "Вернуть",
            category: .tasks,
            isSoftDeleted: true,
            deletedAt: Date()
        )
        container.mainContext.insert(task)

        task.isSoftDeleted = false
        task.deletedAt = nil

        #expect(task.isSoftDeleted == false)
        #expect(task.deletedAt == nil)
    }

    @Test func редактированиеПолей_меняетДанные() throws {
        // После правки название и приоритет обновляются.
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(title: "Старое", priority: .low, category: .tasks)
        container.mainContext.insert(task)

        task.title = "Новое"
        task.priority = .highest
        task.category = .tasks
        task.taskDetails = "Описание"

        #expect(task.title == "Новое")
        #expect(task.priority == .highest)
        #expect(task.category == .tasks)
        #expect(task.taskDetails == "Описание")
    }
}
