//
//  SessionLogDiff.swift
//  BraineeApp
//
//  Строки изменений для журнала сессии: сравнение полей до и после.

import Foundation

enum SessionLogDiff {
    static let none = "нет"

    /// «было → стало»; nil, если не изменилось.
    static func line(_ field: String?, _ old: String, _ new: String) -> String? {
        guard old != new else { return nil }
        let change = "\(old) → \(new)"
        guard let field else { return change }
        return "\(field): \(change)"
    }

    static func quoted(_ text: String) -> String {
        "«\(text)»"
    }

    static func list(_ items: [String]) -> String {
        items.isEmpty ? none : items.joined(separator: ", ")
    }

    static func date(_ date: Date?, hasTime: Bool = false, timeZone: TimeZone = .current) -> String {
        guard let date else { return none }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = timeZone
        formatter.dateFormat = hasTime ? "dd.MM.yyyy HH:mm" : "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    static func onOff(_ value: Bool) -> String {
        value ? "вкл" : "выкл"
    }

    static func time(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

/// Поля задачи, которые видит пользователь в форме; снимок до и после изменения.
struct TaskLogFields: Equatable {
    var title: String
    var deadline: Date?
    var hasDeadlineTime: Bool
    var reminders: [String]
    var priority: String
    var status: String
    var details: String
    var tags: [String]

    init(_ task: TaskItem) {
        title = task.title
        deadline = task.deadline
        hasDeadlineTime = task.hasDeadlineTime
        reminders = task.reminderOffsets.map(\.title)
        priority = task.priority.title
        status = task.status.title
        details = task.taskDetails
        tags = (task.tags ?? []).map(\.name).sorted()
    }

    /// Описание — только факт изменения, без текста (решение владельца, п. 16).
    static func changes(from old: TaskLogFields, to new: TaskLogFields, timeZone: TimeZone = .current) -> [String] {
        typealias D = SessionLogDiff
        var lines: [String?] = [
            D.line("Название", D.quoted(old.title), D.quoted(new.title)),
            D.line(
                "Срок",
                D.date(old.deadline, hasTime: old.hasDeadlineTime, timeZone: timeZone),
                D.date(new.deadline, hasTime: new.hasDeadlineTime, timeZone: timeZone)
            ),
            D.line("Напоминания", D.list(old.reminders), D.list(new.reminders)),
            D.line("Приоритет", old.priority, new.priority),
            D.line("Статус", old.status, new.status)
        ]
        if old.details != new.details {
            lines.append("Описание изменено")
        }
        lines.append(D.line("Теги", D.list(old.tags), D.list(new.tags)))
        return lines.compactMap { $0 }
    }
}
