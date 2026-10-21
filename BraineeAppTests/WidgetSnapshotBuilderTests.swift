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

/// Виджеты экрана блокировки (п. 11): счётчики «сегодня», свежесть снимка, ссылка на «Календарь».
@MainActor
struct LockScreenWidgetSnapshotTests {
    let container: ModelContainer
    let calendar = Calendar(identifier: .gregorian)
    /// Фиксированное «сейчас»: середина дня, далеко от границы суток.
    let now = Date(timeIntervalSince1970: 1_792_000_000)

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func dayOffset(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: now)!
    }

    // Сегодня — только задачи с дедлайном сегодня: выполненные считаются в общем числе, просроченные и корзина — нет.
    @Test func счётчикиСегодня_выполненныеИзОбщегоБезПросроченныхИКорзины() throws {
        let active = TaskItem(title: "Active", deadline: now)
        let done = TaskItem(title: "Done", isCompleted: true, deadline: now, status: .done)
        let overdue = TaskItem(title: "Overdue", deadline: dayOffset(-1))
        let tomorrow = TaskItem(title: "Tomorrow", deadline: dayOffset(1))
        let trashed = TaskItem(title: "Trashed", deadline: now, isSoftDeleted: true, deletedAt: now)
        let tasks = [active, done, overdue, tomorrow, trashed]
        tasks.forEach { container.mainContext.insert($0) }

        let snapshot = WidgetSnapshotBuilder.build(tasks: tasks, habits: [], now: now, calendar: calendar)

        #expect(snapshot.stats.today == 2)
        #expect(snapshot.stats.todayCompleted == 1)
        #expect(snapshot.stats.todayRemaining == 1)
        #expect(snapshot.stats.todayProgress == 0.5)
    }

    // Снимок из старой версии без поля todayCompleted читается, поле — 0.
    @Test func старыйСнимокБезПоля_читаетсяСНулём() throws {
        let json = #"{"total":3,"completed":1,"active":2,"overdue":0,"today":2}"#
        let stats = try JSONDecoder().decode(WidgetStatsSnapshot.self, from: Data(json.utf8))
        #expect(stats.today == 2)
        #expect(stats.todayCompleted == 0)
        #expect(stats.todayRemaining == 2)
    }

    // После полуночи снимок вчерашний: виджет не должен показывать его счётчики «сегодня».
    @Test func свежесть_тотЖеДеньДаСледующийНет() {
        var snapshot = WidgetSnapshot.empty
        snapshot.updatedAt = now
        #expect(snapshot.isFresh(at: now.addingTimeInterval(60), calendar: calendar))
        #expect(!snapshot.isFresh(at: dayOffset(1), calendar: calendar))
    }

    // Ссылка виджета ведёт в «Календарь», ссылка задачи из Календаря — нет.
    @Test func ссылкаКалендаря_распознаётсяТолькоОна() {
        #expect(WidgetSnapshotStore.isCalendarURL(URL(string: "braineeapp://calendar")!))
        #expect(!WidgetSnapshotStore.isCalendarURL(WidgetSnapshotStore.openURL))
        #expect(!WidgetSnapshotStore.isCalendarURL(URL(string: "braineeapp://task/\(UUID().uuidString)")!))
    }
}
