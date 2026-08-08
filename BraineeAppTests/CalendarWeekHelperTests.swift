//
//  CalendarWeekHelperTests.swift
//  BraineeAppTests
//
//  Неделя календаря: 7 дней от начала недели.

import Foundation
import Testing
@testable import BraineeApp

struct CalendarWeekHelperTests {

    @Test func неделяСодержитСемьДней() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // понедельник
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))! // суббота
        let start = CalendarWeekHelper.startOfWeek(containing: day, calendar: calendar)
        let days = CalendarWeekHelper.daysInWeek(starting: start, calendar: calendar)
        #expect(days.count == 7)
        #expect(calendar.component(.weekday, from: start) == 2)
        #expect(calendar.isDate(day, equalTo: days[5], toGranularity: .day))
    }

    @Test func подписьПериода_непустая() {
        let start = CalendarWeekHelper.startOfWeek(containing: Date())
        let title = CalendarWeekHelper.weekRangeTitle(weekStart: start)
        #expect(!title.isEmpty)
        #expect(title.contains("–") || title.contains("-"))
    }
}
