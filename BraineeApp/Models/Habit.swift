//
//  Habit.swift
//  BraineeApp
//
//  Привычка: название и дни выполнения (yyyy-MM-dd). Не больше 7 штук в UI.

import Foundation
import SwiftData

@Model
final class Habit {
    var title: String
    var sortOrder: Int
    var uuid: UUID
    var createdAt: Date
    /// JSON-массив строк дат «yyyy-MM-dd», когда привычка отмечена.
    var completedDaysRaw: String

    static let maxCount = 7
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        title: String,
        sortOrder: Int = 0,
        uuid: UUID = UUID(),
        createdAt: Date = .now,
        completedDayKeys: [String] = []
    ) {
        self.title = title
        self.sortOrder = sortOrder
        self.uuid = uuid
        self.createdAt = createdAt
        self.completedDaysRaw = Self.encodeDays(completedDayKeys)
    }

    var completedDayKeys: [String] {
        get { Self.decodeDays(completedDaysRaw) }
        set { completedDaysRaw = Self.encodeDays(newValue) }
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        completedDayKeys.contains(Self.dayKey(for: day, calendar: calendar))
    }

    func toggleCompletion(on day: Date = .now, calendar: Calendar = .current) {
        let key = Self.dayKey(for: day, calendar: calendar)
        var keys = Set(completedDayKeys)
        if keys.contains(key) {
            keys.remove(key)
        } else {
            keys.insert(key)
        }
        completedDayKeys = keys.sorted()
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        dayKeyFormatter.string(from: calendar.startOfDay(for: date))
    }

    private static func encodeDays(_ days: [String]) -> String {
        let unique = Array(Set(days)).sorted()
        guard let data = try? JSONEncoder().encode(unique),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func decodeDays(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let days = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return days
    }
}
