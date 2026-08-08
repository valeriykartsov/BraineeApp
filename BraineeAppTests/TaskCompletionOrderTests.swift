//
//  TaskCompletionOrderTests.swift
//  BraineeAppTests
//
//  Порядок задач после отметки «выполнено» / снятия галочки.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskCompletionOrderTests {

    @Test func выполнить_переноситВКонецГруппы() throws {
        // После галочки задача должна оказаться внизу своей группы по sortOrder.
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let group = TaskGroup(name: "Папка", category: .tasks, sortOrder: 0)
        context.insert(group)

        let first = TaskItem(title: "A", category: .tasks, sortOrder: 0, group: group)
        let second = TaskItem(title: "B", category: .tasks, sortOrder: 1, group: group)
        let third = TaskItem(title: "C", category: .tasks, sortOrder: 2, group: group)
        context.insert(first)
        context.insert(second)
        context.insert(third)

        first.applyCompletionToggle()
        TaskSortHelper.moveToEnd(of: [first, second, third], task: first)

        #expect(first.isCompleted == true)
        #expect(first.sortOrder > second.sortOrder)
        #expect(first.sortOrder > third.sortOrder)
    }

    @Test func снятьВыполнение_переноситВКонецНезакрытых() throws {
        // Снятие галочки ставит задачу в конец незакрытых (не возвращает на старое место).
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let active1 = TaskItem(title: "Активная 1", category: .tasks, sortOrder: 0)
        let active2 = TaskItem(title: "Активная 2", category: .tasks, sortOrder: 1)
        let done = TaskItem(
            title: "Была готово",
            isCompleted: true,
            category: .tasks,
            status: .done,
            sortOrder: 10
        )
        context.insert(active1)
        context.insert(active2)
        context.insert(done)

        done.applyCompletionToggle()
        #expect(done.isCompleted == false)

        let peers = [active1, active2, done]
        let incomplete = peers.filter { !$0.isCompleted || $0.uuid == done.uuid }
        TaskSortHelper.moveToEnd(of: incomplete, task: done)

        #expect(done.sortOrder > active1.sortOrder)
        #expect(done.sortOrder > active2.sortOrder)

        let sorted = peers.sorted(by: TaskSortHelper.byListMode)
        #expect(sorted.map(\.title) == ["Активная 1", "Активная 2", "Была готово"])
    }

    @Test func список_выполненныеВсегдаНижеАктивных() throws {
        // Даже при меньшем sortOrder выполненная задача ниже незакрытой.
        let container = try TestHelpers.makeContainer()
        let done = TaskItem(
            title: "Готово",
            isCompleted: true,
            category: .tasks,
            status: .done,
            sortOrder: 0
        )
        let active = TaskItem(title: "Активна", category: .tasks, sortOrder: 5)
        container.mainContext.insert(done)
        container.mainContext.insert(active)

        let sorted = [done, active].sorted(by: TaskSortHelper.byListMode)
        #expect(sorted.map(\.title) == ["Активна", "Готово"])
    }
}
