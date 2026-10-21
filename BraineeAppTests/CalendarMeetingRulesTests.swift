//
//  CalendarMeetingRulesTests.swift
//  BraineeAppTests
//
//  Встречи из Календаря на выбранный день (D-37): отбор, порядок, продолжительность.
//  Календарь и даты фиксированные — тесты не зависят от текущего времени и пояса устройства.

import Foundation
import Testing
@testable import BraineeApp

struct CalendarMeetingRulesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    /// 2026-10-21 в Москве.
    private var day: Date { date(21, 0, 0) }

    private func date(_ dayOfMonth: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: dayOfMonth, hour: hour, minute: minute))!
    }

    private func meeting(
        _ title: String,
        _ start: Date,
        _ end: Date,
        allDay: Bool = false,
        calendarTitle: String = "Работа"
    ) -> CalendarMeeting {
        CalendarMeeting(id: title, title: title, start: start, end: end, isAllDay: allDay, calendarTitle: calendarTitle)
    }

    // Порядок: «весь день» первым, дальше по времени начала от раннего к позднему.
    @Test func порядок_весьДеньПервым_далееПоВремени() {
        let events = [
            meeting("Обед", date(21, 13, 0), date(21, 14, 0)),
            meeting("Планёрка", date(21, 9, 0), date(21, 9, 30)),
            meeting("Отпуск", date(21, 0, 0), date(22, 0, 0), allDay: true),
            meeting("Созвон", date(21, 9, 0), date(21, 10, 0))
        ]

        let result = CalendarMeetingRules.meetings(on: day, from: events, calendar: calendar)

        #expect(result.map(\.meeting.title) == ["Отпуск", "Планёрка", "Созвон", "Обед"])
        #expect(result.first?.timing == .allDay)
        #expect(result[1].timing == .starts(date(21, 9, 0)))
    }

    // События календаря «BraineeApp» (это сами задачи) и других дней не показываются.
    @Test func календарьBraineeAppИДругиеДни_неПоказываются() {
        let events = [
            meeting("Задача", date(21, 10, 0), date(21, 10, 30), calendarTitle: CalendarEventRules.calendarTitle),
            meeting("Вчера", date(20, 10, 0), date(20, 11, 0)),
            meeting("Вчера весь день", date(20, 0, 0), date(21, 0, 0), allDay: true),
            meeting("Завтра", date(22, 0, 0), date(22, 1, 0)),
            meeting("Сегодня", date(21, 18, 0), date(21, 19, 0))
        ]

        let result = CalendarMeetingRules.meetings(on: day, from: events, calendar: calendar)

        #expect(result.map(\.meeting.title) == ["Сегодня"])
    }

    // Встреча через полночь: в свой день — с временем начала, на следующий — «до ЧЧ:ММ».
    @Test func встречаЧерезПолночь_наСледующийДеньДо() {
        let night = meeting("Ночной релиз", date(20, 23, 0), date(21, 1, 30))

        let today = CalendarMeetingRules.meetings(on: day, from: [night], calendar: calendar)
        let yesterday = CalendarMeetingRules.meetings(on: date(20, 12, 0), from: [night], calendar: calendar)

        #expect(today.first?.timing == .continuesUntil(date(21, 1, 30)))
        #expect(yesterday.first?.timing == .starts(date(20, 23, 0)))
    }

    // Многодневная встреча (не «весь день»), занимающая сутки целиком, показывается как «весь день».
    @Test func многодневнаяВстреча_середина_весьДень() {
        let conference = meeting("Конференция", date(20, 10, 0), date(22, 18, 0))

        let result = CalendarMeetingRules.meetings(on: day, from: [conference], calendar: calendar)

        #expect(result.first?.timing == .allDay)
    }

    // Продолжительность: минуты, часы, часы с минутами, дни.
    @Test func продолжительность_текст() {
        let start = date(21, 9, 0)
        #expect(CalendarMeetingRules.durationText(from: start, to: date(21, 9, 30)) == "30 мин")
        #expect(CalendarMeetingRules.durationText(from: start, to: date(21, 10, 0)) == "1 ч")
        #expect(CalendarMeetingRules.durationText(from: start, to: date(21, 10, 30)) == "1 ч 30 мин")
        #expect(CalendarMeetingRules.durationText(from: start, to: start) == "0 мин")
        #expect(CalendarMeetingRules.durationText(from: start, to: date(23, 9, 0)) == "2 д")
    }
}
