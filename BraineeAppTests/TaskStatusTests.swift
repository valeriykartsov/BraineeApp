//
//  TaskStatusTests.swift
//  BraineeAppTests
//
//  Статус задачи и связь с чекбоксом выполнения.

import Foundation
import Testing
@testable import BraineeApp

struct TaskStatusTests {

    @Test func чекбоксВкл_ставитГотово() {
        // Отметка выполненной → статус Готово.
        let task = TaskItem(title: "T", status: .new)
        task.applyCompletionToggle()
        #expect(task.status == .done)
        #expect(task.isCompleted == true)
    }

    @Test func чекбоксВыкл_ставитНовая() {
        // Снятие отметки → статус Новая (не «В работе»).
        let task = TaskItem(title: "T", status: .done)
        task.applyCompletionToggle()
        #expect(task.status == .new)
        #expect(task.isCompleted == false)
    }

    @Test func статусВРаботе_неВыполнена() {
        let task = TaskItem(title: "T", status: .inProgress)
        #expect(task.isCompleted == false)
        #expect(task.status == .inProgress)
    }

    @Test func старыйJSONБезStatus_изIsCompleted() throws {
        // Миграция: без statusRaw берём done/new из isCompleted.
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Старая",
          "isCompleted": true,
          "priorityRaw": 1,
          "categoryRaw": "tasks",
          "createdAt": "2024-01-15T10:00:00Z",
          "taskDetails": "",
          "sortOrder": 0,
          "tagIDs": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(TaskRecord.self, from: Data(json.utf8))
        #expect(record.statusRaw == TaskStatus.done.rawValue)
        #expect(record.isCompleted == true)
    }
}
