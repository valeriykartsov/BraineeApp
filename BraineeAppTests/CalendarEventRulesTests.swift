//
//  CalendarEventRulesTests.swift
//  BraineeAppTests
//
//  Правила «задача → событие календаря» (roadmap CAL-2, D-06): чистые функции без EventKit.

import Foundation
import Testing
@testable import BraineeApp

struct CalendarEventRulesTests {
    private let uuid = UUID()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func draft(
        deadline: Date?,
        hasTime: Bool = true,
        isDone: Bool = false,
        isSoftDeleted: Bool = false,
        title: String = "Задача",
        details: String = ""
    ) -> CalendarEventDraft? {
        CalendarEventRules.draft(
            title: title,
            deadline: deadline,
            hasDeadlineTime: hasTime,
            isDone: isDone,
            isSoftDeleted: isSoftDeleted,
            details: details,
            uuid: uuid,
            calendar: calendar
        )
    }

    // Задача без даты в календарь не попадает (D-06).
    @Test func задачаБезДаты_неЭкспортируется() {
        #expect(draft(deadline: nil) == nil)
    }

    // Выполненная и мягко удалённая задача — события нет (D-06).
    @Test func выполненнаяИУдалённая_неЭкспортируются() {
        #expect(draft(deadline: date(21, 10), isDone: true) == nil)
        #expect(draft(deadline: date(21, 10), isSoftDeleted: true) == nil)
    }

    // Задача со временем — событие на 30 минут с начала дедлайна (D-06).
    @Test func задачаСоВременем_событие30Минут() throws {
        let result = try #require(draft(deadline: date(21, 10, 15)))
        #expect(!result.isAllDay)
        #expect(result.start == date(21, 10, 15))
        #expect(result.end == date(21, 10, 45))
    }

    // Дата без времени — событие на весь день с начала суток.
    @Test func датаБезВремени_событиеНаВесьДень() throws {
        let result = try #require(draft(deadline: date(21, 17), hasTime: false))
        #expect(result.isAllDay)
        #expect(result.start == date(21, 0))
    }

    // Название и описание обрезаются; пустое название заменяется, пустое описание — nil.
    @Test func названиеИОписание_нормализуются() throws {
        let empty = try #require(draft(deadline: date(21, 10), title: "  ", details: " \n"))
        #expect(empty.title == "Без названия")
        #expect(empty.notes == nil)
        let filled = try #require(draft(deadline: date(21, 10), title: " Купить хлеб ", details: " в магазине "))
        #expect(filled.title == "Купить хлеб")
        #expect(filled.notes == "в магазине")
    }

    // Метка события ведёт обратно к задаче; чужие ссылки не распознаются как задачи.
    @Test func меткаСобытия_содержитUUIDЗадачи() throws {
        let result = try #require(draft(deadline: date(21, 10)))
        #expect(CalendarEventRules.taskUUID(from: result.url) == uuid)
        #expect(CalendarEventRules.taskUUID(from: URL(string: "braineeapp://cal1-spike/\(uuid)")) == nil)
        #expect(CalendarEventRules.taskUUID(from: URL(string: "https://example.com/task/\(uuid)")) == nil)
        #expect(CalendarEventRules.taskUUID(from: nil) == nil)
    }

    // Событие на весь день, прочитанное из EventKit с концом дня, не считается изменённым.
    @Test func событиеНаВесьДень_сКонцомДня_неПереписывается() throws {
        let wanted = try #require(draft(deadline: date(21, 9), hasTime: false))
        var stored = wanted
        stored.end = date(21, 23, 59)
        stored.notes = ""
        #expect(!CalendarEventRules.needsUpdate(stored, to: wanted, calendar: calendar))
    }

    // Смена дня, времени, названия или типа события — событие нужно переписать.
    @Test func изменённоеСобытие_переписывается() throws {
        let wanted = try #require(draft(deadline: date(21, 10)))
        #expect(!CalendarEventRules.needsUpdate(wanted, to: wanted, calendar: calendar))

        var moved = wanted
        moved.start = date(21, 11)
        moved.end = date(21, 11, 30)
        #expect(CalendarEventRules.needsUpdate(moved, to: wanted, calendar: calendar))

        var renamed = wanted
        renamed.title = "Другое"
        #expect(CalendarEventRules.needsUpdate(renamed, to: wanted, calendar: calendar))

        let allDay = try #require(draft(deadline: date(21, 10), hasTime: false))
        #expect(CalendarEventRules.needsUpdate(wanted, to: allDay, calendar: calendar))

        let otherDay = try #require(draft(deadline: date(22, 10), hasTime: false))
        #expect(CalendarEventRules.needsUpdate(allDay, to: otherDay, calendar: calendar))
    }
}
