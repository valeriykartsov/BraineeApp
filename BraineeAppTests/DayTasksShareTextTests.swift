//
//  DayTasksShareTextTests.swift
//  BraineeAppTests
//
//  Текст «Задачи на день» для «Поделиться» (п. 23a, D-38): только то, что разрешено отправлять.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct DayTasksShareTextTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    /// Четверг, 22 октября 2026 года, в часах:минутах по Москве.
    private func day(_ hour: Int = 12, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 22 + dayOffset, hour: hour, minute: minute))!
    }

    private func task(
        _ title: String,
        at date: Date,
        hasTime: Bool = true,
        completed: Bool = false,
        trashed: Bool = false,
        sortOrder: Int = 0
    ) -> TaskItem {
        let task = TaskItem(
            title: title,
            isCompleted: completed,
            deadline: date,
            hasDeadlineTime: hasTime,
            status: completed ? .done : .new,
            taskDetails: "секретное описание",
            sortOrder: sortOrder,
            isSoftDeleted: trashed
        )
        container.mainContext.insert(task)
        return task
    }

    // Со временем — по времени, без времени — в конце; описания, выполненные, корзина и другие дни не попадают.
    @Test func составИПорядок_толькоРазрешённое() {
        let tasks = [
            task("Отчёт", at: day(15)),
            task("Купить продукты", at: day(), hasTime: false, sortOrder: 2),
            task("Созвон", at: day(10)),
            task("Позвонить маме", at: day(), hasTime: false, sortOrder: 1),
            task("Сделано", at: day(9), completed: true),
            task("В корзине", at: day(11), trashed: true),
            task("Вчерашняя", at: day(dayOffset: -1)),
            task("Завтрашняя", at: day(dayOffset: 1))
        ]

        let text = DayTasksShareText.make(tasks: tasks, day: day(), calendar: calendar)

        #expect(text == """
        Задачи на чт, 22 октября
        10:00 Созвон
        15:00 Отчёт
        • Позвонить маме
        • Купить продукты
        """)
        #expect(!text.contains("описание"))
    }

    // Пустой день — одна строка «задач нет».
    @Test func пустойДень_задачНет() {
        let tasks = [task("Сделано", at: day(9), completed: true)]
        #expect(DayTasksShareText.make(tasks: tasks, day: day(), calendar: calendar) == "Задачи на чт, 22 октября: задач нет")
    }
}
