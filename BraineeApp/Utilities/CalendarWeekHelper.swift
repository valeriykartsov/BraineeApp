//
//  CalendarWeekHelper.swift
//  BraineeApp
//
//  Неделя по календарю пользователя: границы и подпись периода.

import Foundation

enum CalendarWeekHelper {
    /// Понедельник (или первый день недели локали) недели, содержащей date.
    static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let firstWeekday = calendar.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromStart, to: day) ?? day
    }

    static func daysInWeek(starting weekStart: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: weekStart))
        }
    }

    static func weekRangeTitle(weekStart: Date, calendar: Calendar = .current) -> String {
        let days = daysInWeek(starting: weekStart, calendar: calendar)
        guard let first = days.first, let last = days.last else { return "" }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "d"
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "ru_RU")
        monthFormatter.dateFormat = "MMM"
        let firstDay = dayFormatter.string(from: first)
        let lastDay = dayFormatter.string(from: last)
        let firstMonth = monthFormatter.string(from: first).replacingOccurrences(of: ".", with: "")
        let lastMonth = monthFormatter.string(from: last).replacingOccurrences(of: ".", with: "")
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(firstDay)–\(lastDay) \(lastMonth)"
        }
        return "\(firstDay) \(firstMonth) – \(lastDay) \(lastMonth)"
    }

    static func weekdayShort(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}
