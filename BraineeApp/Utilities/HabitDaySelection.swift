//
//  HabitDaySelection.swift
//  BraineeApp
//
//  Выбор дня для отметок привычек: сегодня и до 14 дней назад.

import Foundation

enum HabitDaySelection {
    /// Сколько дней назад можно уйти от сегодня (сегодня − 14).
    static let maxDaysBack = 14

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func earliestAllowed(
        relativeTo today: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let todayStart = startOfDay(today, calendar: calendar)
        return calendar.date(byAdding: .day, value: -maxDaysBack, to: todayStart) ?? todayStart
    }

    /// День в окне [сегодня − 14 … сегодня].
    static func clamp(
        _ day: Date,
        relativeTo today: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let dayStart = startOfDay(day, calendar: calendar)
        let todayStart = startOfDay(today, calendar: calendar)
        let earliest = earliestAllowed(relativeTo: today, calendar: calendar)
        if dayStart > todayStart { return todayStart }
        if dayStart < earliest { return earliest }
        return dayStart
    }

    static func canMoveBack(
        _ day: Date,
        relativeTo today: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let current = clamp(day, relativeTo: today, calendar: calendar)
        return current > earliestAllowed(relativeTo: today, calendar: calendar)
    }

    static func canMoveForward(
        _ day: Date,
        relativeTo today: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let current = clamp(day, relativeTo: today, calendar: calendar)
        return current < startOfDay(today, calendar: calendar)
    }

    static func shifting(
        _ day: Date,
        by days: Int,
        relativeTo today: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let base = clamp(day, relativeTo: today, calendar: calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return clamp(shifted, relativeTo: today, calendar: calendar)
    }

    /// Подпись: «Сегодня», «Вчера» или краткая дата.
    static func title(
        for day: Date,
        relativeTo today: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = Locale(identifier: "ru_RU")
    ) -> String {
        let dayStart = clamp(day, relativeTo: today, calendar: calendar)
        if calendar.isDate(dayStart, inSameDayAs: startOfDay(today, calendar: calendar)) {
            return "Сегодня"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay(today, calendar: calendar)),
           calendar.isDate(dayStart, inSameDayAs: yesterday) {
            return "Вчера"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: dayStart)
    }
}
