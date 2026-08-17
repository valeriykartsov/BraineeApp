//
//  AppBadgeCounterTests.swift
//  BraineeAppTests
//

import Foundation
import Testing
@testable import BraineeApp

@MainActor
struct AppBadgeCounterTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!
    }

    private func task(
        deadline: Date?,
        hasTime: Bool = false,
        completed: Bool = false,
        softDeleted: Bool = false
    ) -> TaskItem {
        TaskItem(
            title: "T",
            isCompleted: completed,
            deadline: deadline,
            hasDeadlineTime: hasTime,
            isSoftDeleted: softDeleted
        )
    }

    @Test func режимВыкл_всегдаНоль() {
        // Выкл — ни иконка, ни вкладка не показывают число.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tasks = [task(deadline: yesterday)]
        #expect(AppBadgeCounter.count(tasks: tasks, mode: .off, now: now, calendar: calendar) == 0)
        #expect(AppBadgeCounter.displayText(for: 0) == nil)
    }

    @Test func просроченные_считаетТолькоOverdue() {
        // Сегодняшние без просрочки по времени не входят в режим overdue.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let today = calendar.startOfDay(for: now)
        let tasks = [
            task(deadline: yesterday),
            task(deadline: today),
            task(deadline: yesterday, completed: true),
            task(deadline: yesterday, softDeleted: true)
        ]
        #expect(AppBadgeCounter.count(tasks: tasks, mode: .overdue, now: now, calendar: calendar) == 1)
    }

    @Test func сегодняИПросроченные_объединяетБезДублей() {
        // Просроченная «сегодня по времени» и due today считаются один раз каждая.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let todayMorning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let tasks = [
            task(deadline: yesterday),
            task(deadline: todayMorning, hasTime: true),
            task(deadline: calendar.startOfDay(for: now))
        ]
        // yesterday overdue; todayMorning with time 08:00 < 12:00 → overdue; startOfDay today → due today
        // todayMorning is both overdue AND today — still one task
        #expect(AppBadgeCounter.count(tasks: tasks, mode: .todayAndOverdue, now: now, calendar: calendar) == 3)
    }

    @Test func displayText_кап99() {
        #expect(AppBadgeCounter.displayText(for: 5) == "5")
        #expect(AppBadgeCounter.displayText(for: 99) == "99")
        #expect(AppBadgeCounter.displayText(for: 100) == "99+")
    }
}
