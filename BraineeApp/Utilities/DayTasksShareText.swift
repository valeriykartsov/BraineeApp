//
//  DayTasksShareText.swift
//  BraineeApp
//
//  Текст «Задачи на день» для системного меню «Поделиться» (п. 23a, D-38).
//  Только невыполненные задачи с дедлайном в этот день: время и название — без описаний,
//  тегов, папок, приоритетов, выполненных, просроченных и встреч. Ничего не отправляет сам.

import Foundation

enum DayTasksShareText {
    static func make(tasks: [TaskItem], day: Date, calendar: Calendar = .current) -> String {
        let dueTasks = tasks.filter { task in
            !task.isSoftDeleted && !task.isCompleted && task.isDue(on: day, calendar: calendar)
        }
        let header = "Задачи на \(dayTitle(day, timeZone: calendar.timeZone))"
        guard !dueTasks.isEmpty else { return "\(header): задач нет" }

        // Сначала со временем — по времени, затем без времени — в порядке списка.
        let timed = dueTasks
            .filter(\.hasDeadlineTime)
            .sorted { ($0.deadline ?? .distantFuture, $0.sortOrder) < ($1.deadline ?? .distantFuture, $1.sortOrder) }
        let untimed = dueTasks
            .filter { !$0.hasDeadlineTime }
            .sorted { $0.sortOrder < $1.sortOrder }

        var lines = [header]
        lines += timed.map { "\(time($0.deadline, timeZone: calendar.timeZone)) \($0.title)" }
        lines += untimed.map { "• \($0.title)" }
        return lines.joined(separator: "\n")
    }

    /// «чт, 23 октября». День недели — строчными: в iOS 27 формат даёт «Чт».
    static func dayTitle(_ day: Date, timeZone: TimeZone) -> String {
        let weekday = formatted(day, "EE", timeZone: timeZone).lowercased(with: Locale(identifier: "ru_RU"))
        return "\(weekday), \(formatted(day, "d MMMM", timeZone: timeZone))"
    }

    private static func time(_ date: Date?, timeZone: TimeZone) -> String {
        guard let date else { return "" }
        return formatted(date, "HH:mm", timeZone: timeZone)
    }

    private static func formatted(_ date: Date, _ format: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
