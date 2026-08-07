//
//  TaskSortHelperTests.swift
//  BraineeAppTests
//
//  Порядок задач в режимах «По дате» и «План на день».

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskSortHelperTests {

    @Test func поДате_просроченныеВышеСегодняшних() throws {
        // В режиме «По дате» просроченные идут раньше задач на сегодня.
        let container = try TestHelpers.makeContainer()
        let overdue = TaskItem(
            title: "Просрочена",
            deadline: TestHelpers.daysFromNow(-1),
            priority: .low,
            category: .career,
            sortOrder: 0
        )
        let today = TaskItem(
            title: "Сегодня",
            deadline: Date(),
            priority: .highest,
            category: .career,
            sortOrder: 0
        )
        container.mainContext.insert(overdue)
        container.mainContext.insert(today)

        let sorted = [today, overdue].sorted(by: TaskSortHelper.byDateMode)
        #expect(sorted.map(\.title) == ["Просрочена", "Сегодня"])
    }

    @Test func поДате_безДатыВКонце() throws {
        // Задачи без дедлайна — после задач с датой.
        let container = try TestHelpers.makeContainer()
        let withDate = TaskItem(
            title: "С датой",
            deadline: TestHelpers.daysFromNow(5),
            category: .career,
            sortOrder: 0
        )
        let noDate = TaskItem(title: "Без даты", category: .career, sortOrder: 0)
        container.mainContext.insert(withDate)
        container.mainContext.insert(noDate)

        let sorted = [noDate, withDate].sorted(by: TaskSortHelper.byDateMode)
        #expect(sorted.first?.title == "С датой")
        #expect(sorted.last?.title == "Без даты")
    }

    @Test func планНаДень_активныеВышеВыполненных() throws {
        // В «Плане на день» невыполненные выше выполненных.
        let container = try TestHelpers.makeContainer()
        let done = TaskItem(
            title: "Готово",
            isCompleted: true,
            deadline: Date(),
            priority: .highest,
            category: .sport,
            sortOrder: 0
        )
        let active = TaskItem(
            title: "Ещё нет",
            isCompleted: false,
            deadline: Date(),
            priority: .low,
            category: .sport,
            sortOrder: 0
        )
        container.mainContext.insert(done)
        container.mainContext.insert(active)

        let sorted = [done, active].sorted(by: TaskSortHelper.byDayPlan)
        #expect(sorted.map(\.title) == ["Ещё нет", "Готово"])
    }
}
