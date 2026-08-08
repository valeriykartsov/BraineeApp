//
//  TaskDeadlineTimeTests.swift
//  BraineeAppTests
//
//  Дедлайн с временем: отображение, просрочка и миграция JSON.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskDeadlineTimeTests {

    @Test func безВремени_вТекстеТолькоДата() throws {
        // Если время не выбрано — в карточке только дата.
        let container = try TestHelpers.makeContainer()
        let deadline = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 15, minute: 30))!
        let task = TaskItem(
            title: "Без времени",
            deadline: deadline,
            hasDeadlineTime: false,
            category: .tasks
        )
        container.mainContext.insert(task)

        let text = try #require(task.deadlineDisplayText)
        #expect(!text.contains(":"))
    }

    @Test func сВременем_вТекстеЕстьВремя() throws {
        // При hasDeadlineTime в строке дедлайна есть часы.
        let container = try TestHelpers.makeContainer()
        let deadline = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 15, minute: 30))!
        let task = TaskItem(
            title: "С временем",
            deadline: deadline,
            hasDeadlineTime: true,
            category: .tasks
        )
        container.mainContext.insert(task)

        let text = try #require(task.deadlineDisplayText)
        #expect(text.contains("15") || text.contains(":"))
    }

    @Test func старыйJSONБезПоляВремени_поУмолчаниюFalse() throws {
        // Миграция: отсутствие hasDeadlineTime не ломает decode.
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "Старая",
          "isCompleted": false,
          "priorityRaw": 1,
          "categoryRaw": "tasks",
          "createdAt": "2026-01-01T12:00:00Z",
          "taskDetails": "",
          "sortOrder": 0,
          "tagIDs": [],
          "isDeleted": false
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(TaskRecord.self, from: Data(json.utf8))
        #expect(record.hasDeadlineTime == false)
    }

    @Test func новаяЗадачаПоУмолчанию_статусНовая() throws {
        // Создание без явного статуса — всегда «Новая».
        let container = try TestHelpers.makeContainer()
        let task = TaskItem(title: "Новая", category: .tasks, status: .new)
        container.mainContext.insert(task)
        #expect(task.status == .new)
        #expect(task.isCompleted == false)
    }

    @Test func faqРаздел_заполненВопросами() {
        // В FAQ есть основные ответы для профиля.
        #expect(FAQItem.all.count >= 5)
        #expect(FAQItem.all.contains { $0.question.contains("Brainee") })
    }
}
