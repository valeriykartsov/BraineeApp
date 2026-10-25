//
//  CalendarDayOrderTests.swift
//  BraineeAppTests
//
//  Порядок «Задач дня» во вкладке «Календарь» (п. 48): приоритет, затем время.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct CalendarDayOrderTests {
    /// Контейнер живёт столько же, сколько тест (см. CLAUDE.md).
    private let container: ModelContainer
    /// Фиксированный день — тест не зависит от текущего времени.
    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 26))!

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func task(
        _ title: String,
        priority: TaskPriority,
        hour: Int? = nil,
        done: Bool = false,
        sortOrder: Int = 0
    ) -> TaskItem {
        let deadline = hour.flatMap { Calendar.current.date(bySettingHour: $0, minute: 0, second: 0, of: day) } ?? day
        let task = TaskItem(
            title: title,
            isCompleted: done,
            deadline: deadline,
            hasDeadlineTime: hour != nil,
            priority: priority,
            sortOrder: sortOrder
        )
        container.mainContext.insert(task)
        return task
    }

    private func ordered(_ tasks: [TaskItem]) -> [String] {
        tasks.sorted(by: TaskSortHelper.byCalendarDay).map(\.title)
    }

    // Приоритет важнее времени: «Наивысший» в 18:00 выше «Низкого» в 9:00.
    @Test func разныеПриоритеты_отНаивысшегоКНизкому() {
        let tasks = [
            task("Низкий 9", priority: .low, hour: 9),
            task("Средний 10", priority: .medium, hour: 10),
            task("Высокий 11", priority: .high, hour: 11),
            task("Наивысший 18", priority: .highest, hour: 18)
        ]

        #expect(ordered(tasks) == ["Наивысший 18", "Высокий 11", "Средний 10", "Низкий 9"])
    }

    // Внутри приоритета — со временем по времени, затем без времени по порядку в списке.
    @Test func одинПриоритет_сначалаПоВремениЗатемБезВремени() {
        let tasks = [
            task("Без времени 2", priority: .high, sortOrder: 2),
            task("В 15", priority: .high, hour: 15),
            task("Без времени 1", priority: .high, sortOrder: 1),
            task("В 8", priority: .high, hour: 8)
        ]

        #expect(ordered(tasks) == ["В 8", "В 15", "Без времени 1", "Без времени 2"])
    }

    // Выполненные — под всеми невыполненными, между собой по тем же правилам.
    @Test func выполненные_внизуПоТемЖеПравилам() {
        let tasks = [
            task("Готово низкий", priority: .low, hour: 7, done: true),
            task("Готово наивысший", priority: .highest, done: true),
            task("Открыта низкий", priority: .low),
            task("Открыта высокий", priority: .high, hour: 20)
        ]

        #expect(ordered(tasks) == ["Открыта высокий", "Открыта низкий", "Готово наивысший", "Готово низкий"])
    }

    // «Поделиться» (D-38) не меняется: там задачи по времени, а не по приоритету.
    @Test func поделиться_порядокПоВремени() {
        let tasks = [
            task("Наивысший 18", priority: .highest, hour: 18),
            task("Низкий 9", priority: .low, hour: 9)
        ]

        let lines = DayTasksShareText.make(tasks: tasks, day: day).components(separatedBy: "\n")

        #expect(lines.dropFirst().map { $0.hasSuffix("Низкий 9") } == [true, false])
        #expect(lines.last?.hasSuffix("Наивысший 18") == true)
    }
}
