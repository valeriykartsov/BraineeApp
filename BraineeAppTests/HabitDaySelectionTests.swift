//
//  HabitDaySelectionTests.swift
//  BraineeAppTests
//

import Foundation
import Testing
@testable import BraineeApp

struct HabitDaySelectionTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        return cal
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
    }

    @Test func глубина_ровно14ДнейНазад() {
        // Окно: сегодня и 14 дней назад — дальше нельзя.
        let earliest = HabitDaySelection.earliestAllowed(relativeTo: today, calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: today))!
        #expect(calendar.isDate(earliest, inSameDayAs: expected))
        #expect(HabitDaySelection.maxDaysBack == 14)
    }

    @Test func clamp_обрезаетБудущееИСлишкомСтарое() {
        // Завтра → сегодня; раньше окна → earliest.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tooOld = calendar.date(byAdding: .day, value: -30, to: today)!
        #expect(
            calendar.isDate(
                HabitDaySelection.clamp(tomorrow, relativeTo: today, calendar: calendar),
                inSameDayAs: today
            )
        )
        #expect(
            calendar.isDate(
                HabitDaySelection.clamp(tooOld, relativeTo: today, calendar: calendar),
                inSameDayAs: HabitDaySelection.earliestAllowed(relativeTo: today, calendar: calendar)
            )
        )
    }

    @Test func навигация_границыВперёдНазад() {
        // На сегодня нельзя вперёд; на earliest нельзя назад.
        #expect(!HabitDaySelection.canMoveForward(today, relativeTo: today, calendar: calendar))
        #expect(HabitDaySelection.canMoveBack(today, relativeTo: today, calendar: calendar))

        let earliest = HabitDaySelection.earliestAllowed(relativeTo: today, calendar: calendar)
        #expect(!HabitDaySelection.canMoveBack(earliest, relativeTo: today, calendar: calendar))
        #expect(HabitDaySelection.canMoveForward(earliest, relativeTo: today, calendar: calendar))
    }

    @Test func сдвиг_наДеньВПределахОкна() {
        // −1 от сегодня → вчера; +1 от вчера → сегодня.
        let expectedYesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: calendar.startOfDay(for: today)
        )!
        let yesterday = HabitDaySelection.shifting(today, by: -1, relativeTo: today, calendar: calendar)
        #expect(calendar.isDate(yesterday, inSameDayAs: expectedYesterday))
        let back = HabitDaySelection.shifting(yesterday, by: 1, relativeTo: today, calendar: calendar)
        #expect(calendar.isDate(back, inSameDayAs: today))
    }

    @Test func подпись_сегодняВчераИДата() {
        // Сегодня / Вчера — спец. подписи; остальные — дата.
        #expect(HabitDaySelection.title(for: today, relativeTo: today, calendar: calendar) == "Сегодня")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        #expect(HabitDaySelection.title(for: yesterday, relativeTo: today, calendar: calendar) == "Вчера")
        let older = calendar.date(byAdding: .day, value: -3, to: today)!
        let title = HabitDaySelection.title(for: older, relativeTo: today, calendar: calendar)
        #expect(title != "Сегодня")
        #expect(title != "Вчера")
        #expect(!title.isEmpty)
    }
}
