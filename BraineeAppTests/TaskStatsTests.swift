//
//  TaskStatsTests.swift
//  BraineeAppTests
//
//  Расчёты дашборда: прогресс, просроченные, сегодня, пустой список.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskStatsTests {

    @Test func пустойСписок_нулиБезКраша() {
        // Нет задач — все счётчики 0, прогресс 0 (без деления на ноль).
        let stats = TaskStats.compute(from: [])
        #expect(stats.total == 0)
        #expect(stats.completed == 0)
        #expect(stats.active == 0)
        #expect(stats.overdue == 0)
        #expect(stats.today == 0)
        #expect(stats.progress == 0)
    }

    @Test func смешанныеЗадачи_считаетВерно() throws {
        // Одна выполнена сегодня, одна просрочена → цифры дашборда.
        let container = try TestHelpers.makeContainer()
        let doneToday = TaskItem(
            title: "Готово сегодня",
            isCompleted: true,
            deadline: Date(),
            category: .tasks
        )
        let overdue = TaskItem(
            title: "Просрочена",
            deadline: TestHelpers.daysFromNow(-3),
            category: .tasks
        )
        container.mainContext.insert(doneToday)
        container.mainContext.insert(overdue)

        let stats = TaskStats.compute(from: [doneToday, overdue])
        #expect(stats.total == 2)
        #expect(stats.completed == 1)
        #expect(stats.active == 1)
        #expect(stats.overdue == 1)
        #expect(stats.today == 1)
        #expect(stats.progress == 0.5)
    }

    @Test func удалённыеНеДолжныПопадатьЕслиИхНеПередали() throws {
        // Дашборд получает уже отфильтрованный список активных.
        let container = try TestHelpers.makeContainer()
        let active = TaskItem(title: "Активная", category: .tasks)
        let deleted = TaskItem(
            title: "Удалённая",
            category: .tasks,
            isSoftDeleted: true,
            deletedAt: Date()
        )
        container.mainContext.insert(active)
        container.mainContext.insert(deleted)

        let activeOnly = [active, deleted].filter { !$0.isSoftDeleted }
        let stats = TaskStats.compute(from: activeOnly)
        #expect(stats.total == 1)
    }
}
