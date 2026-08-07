//
//  SoftDeleteAndGroupTests.swift
//  BraineeAppTests
//
//  Удаление группы не удаляет задачи; окончательное удаление убирает из контекста.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct SoftDeleteAndGroupTests {

    @Test func удалениеГруппы_задачиОтвязываютсяНоЖивут() throws {
        // Как в UI: удалили папку — задачи остаются без группы (nullify).
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let group = TaskGroup(name: "Папка", category: .career)
        let task = TaskItem(title: "В папке", category: .career, group: group)
        context.insert(group)
        context.insert(task)
        try context.save()

        context.delete(group)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        let groups = try context.fetch(FetchDescriptor<TaskGroup>())
        #expect(groups.isEmpty)
        #expect(tasks.count == 1)
        #expect(tasks[0].group == nil)
        #expect(tasks[0].title == "В папке")
    }

    @Test func окончательноеУдаление_убираетЗадачуИзКонтекста() throws {
        // Permanent delete из «Удалённых» — modelContext.delete.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let task = TaskItem(
            title: "Навсегда",
            category: .career,
            isSoftDeleted: true,
            deletedAt: Date()
        )
        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(remaining.isEmpty)
    }

    @Test func удалениеПоследнейЗадачи_контекстПустойБезОшибки() throws {
        // Граничный случай: удалили единственную задачу — список пуст, краша нет.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let task = TaskItem(title: "Единственная", category: .sport)
        context.insert(task)
        try context.save()

        task.isSoftDeleted = true
        task.deletedAt = Date()
        context.delete(task)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }
}
