//
//  WidgetSnapshotBuilderTests.swift
//  BraineeAppTests
//
//  Снимок виджета: задачи сегодня по приоритету и прогресс привычек.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct WidgetSnapshotBuilderTests {

    @Test func todayTasks_триСамыхПриоритетных() throws {
        // На сегодня берём незакрытые, сортируем по приоритету, в снимке до 5.
        let container = try TestHelpers.makeContainer()
        let today = Date()
        let low = TaskItem(title: "Low", deadline: today, hasDeadlineTime: false, priority: .low)
        let high = TaskItem(title: "High", deadline: today, hasDeadlineTime: false, priority: .high)
        let highest = TaskItem(title: "Highest", deadline: today, hasDeadlineTime: false, priority: .highest)
        let done = TaskItem(
            title: "Done",
            isCompleted: true,
            deadline: today,
            priority: .highest,
            status: .done
        )
        for task in [low, high, highest, done] {
            container.mainContext.insert(task)
        }

        let snapshot = WidgetSnapshotBuilder.build(
            tasks: [low, high, highest, done],
            habits: []
        )
        #expect(snapshot.todayTasks.map(\.title) == ["Highest", "High", "Low"])
        #expect(snapshot.stats.today >= 3)
    }

    @Test func habitsProgress_считаетОтметкиЗаСегодня() throws {
        let container = try TestHelpers.makeContainer()
        let calendar = Calendar.current
        let todayKey = Habit.dayKey(for: .now, calendar: calendar)
        let h1 = Habit(title: "A", sortOrder: 0, completedDayKeys: [todayKey])
        let h2 = Habit(title: "B", sortOrder: 1, completedDayKeys: [])
        container.mainContext.insert(h1)
        container.mainContext.insert(h2)

        let snapshot = WidgetSnapshotBuilder.build(tasks: [], habits: [h1, h2])
        #expect(snapshot.habitsTotal == 2)
        #expect(snapshot.habitsCompletedToday == 1)
        #expect(snapshot.habitsProgress == 0.5)
    }
}
