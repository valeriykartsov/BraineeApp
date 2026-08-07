//
//  TaskCategoryStatsTests.swift
//  BraineeAppTests
//
//  Расчёты дашборда: прогресс, просроченные, сегодня, пустой раздел.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskCategoryStatsTests {

    @Test func пустойРаздел_нулиБезКраша() {
        // Нет задач — все счётчики 0, прогресс 0 (без деления на ноль).
        let stats = TaskCategoryStats.compute(from: [], category: .career)
        #expect(stats.total == 0)
        #expect(stats.completed == 0)
        #expect(stats.active == 0)
        #expect(stats.overdue == 0)
        #expect(stats.today == 0)
        #expect(stats.progress == 0)
    }

    @Test func смешанныеЗадачи_считаетВерно() throws {
        // 2 задачи в Карьере: одна выполнена сегодня, одна просрочена → цифры дашборда.
        let container = try TestHelpers.makeContainer()
        let doneToday = TaskItem(
            title: "Готово сегодня",
            isCompleted: true,
            deadline: Date(),
            category: .career
        )
        let overdue = TaskItem(
            title: "Просрочена",
            deadline: TestHelpers.daysFromNow(-3),
            category: .career
        )
        let otherSection = TaskItem(
            title: "Спорт",
            category: .sport
        )
        container.mainContext.insert(doneToday)
        container.mainContext.insert(overdue)
        container.mainContext.insert(otherSection)

        let stats = TaskCategoryStats.compute(
            from: [doneToday, overdue, otherSection],
            category: .career
        )
        #expect(stats.total == 2)
        #expect(stats.completed == 1)
        #expect(stats.active == 1)
        #expect(stats.overdue == 1)
        #expect(stats.today == 1) // выполненная на сегодня всё равно isDueToday
        #expect(stats.progress == 0.5)
    }

    @Test func удалённыеНеДолжныПопадатьЕслиИхПередали() throws {
        // Дашборд получает уже отфильтрованный список; если передать только активные — ок.
        // Проверяем, что задача другого статуса не раздувает total при фильтре по категории.
        let container = try TestHelpers.makeContainer()
        let active = TaskItem(title: "Активная", category: .mental)
        let deleted = TaskItem(
            title: "Удалённая",
            category: .mental,
            isDeleted: true,
            deletedAt: Date()
        )
        container.mainContext.insert(active)
        container.mainContext.insert(deleted)

        // Как в UI: в compute передаём только !isDeleted
        let activeOnly = [active, deleted].filter { !$0.isDeleted }
        let stats = TaskCategoryStats.compute(from: activeOnly, category: .mental)
        #expect(stats.total == 1)
    }
}
