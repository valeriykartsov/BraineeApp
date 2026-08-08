//
//  TaskDragPayloadTests.swift
//  BraineeAppTests
//
//  Разбор payload drag-and-drop: UUID задачи из перетаскиваемой строки.

import Foundation
import Testing
@testable import BraineeApp

struct TaskDragPayloadTests {
    // Валидный UUID из payload находит активную задачу в списке.
    @Test func валидныйUUID_возвращаетЗадачуИзСписка() {
        let task = TaskItem(title: "Перетащить", category: .tasks)
        let other = TaskItem(title: "Другая", category: .tasks)

        let found = TaskDragPayload.task(in: [task, other], from: [task.uuid.uuidString])
        #expect(found?.uuid == task.uuid)
    }

    // Мягко удалённая задача не участвует в drop.
    @Test func мягкоУдалённаяЗадача_неВозвращается() {
        let task = TaskItem(title: "Удалена", category: .tasks)
        task.isSoftDeleted = true
        task.deletedAt = .now

        let found = TaskDragPayload.task(in: [task], from: [task.uuid.uuidString])
        #expect(found == nil)
    }

    // Битый или пустой payload не роняет логику.
    @Test func битыйИлиПустойPayload_возвращаетNil() {
        let task = TaskItem(title: "Есть", category: .tasks)
        #expect(TaskDragPayload.task(in: [task], from: []) == nil)
        #expect(TaskDragPayload.task(in: [task], from: ["not-a-uuid"]) == nil)
        #expect(TaskDragPayload.task(in: [task], from: [UUID().uuidString]) == nil)
    }
}
