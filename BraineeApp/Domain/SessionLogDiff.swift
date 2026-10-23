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
    /// Только у задачи со временем (D-40); nil — длительности нет.
    var duration: String?
    var reminders: [String]
    var priority: String
    var status: String
    var details: String
    var tags: [String]
    /// uuid → (текст, отметка); в журнал попадают только числа (D-41).
    var subtasks: [UUID: SubtaskState]

    struct SubtaskState: Equatable {
        var title: String
        var isDone: Bool
    }

    init(_ task: TaskItem) {
        title = task.title
        deadline = task.deadline
        hasDeadlineTime = task.hasDeadlineTime
        duration = task.hasDeadlineTime ? TaskDuration.title(task.effectiveDurationMinutes) : nil
        reminders = task.reminderOffsets.map(\.title)
        priority = task.priority.title
        status = task.status.title
        details = task.taskDetails
        tags = (task.tags ?? []).map(\.name).sorted()
        subtasks = Dictionary(
            task.subtasks.map { ($0.uuid, SubtaskState(title: $0.title, isDone: $0.isDone)) },
            uniquingKeysWith: { first, _ in first }
        )
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
            // Время появилось или убрано — это видно в «Сроке»; длительность — только когда время есть до и после.
            old.duration.flatMap { before in new.duration.flatMap { D.line("Длительность", before, $0) } },
            D.line("Напоминания", D.list(old.reminders), D.list(new.reminders)),
            D.line("Приоритет", old.priority, new.priority),
            D.line("Статус", old.status, new.status)
        ]
        if old.details != new.details {
            lines.append("Описание изменено")
        }
        lines.append(D.line("Теги", D.list(old.tags), D.list(new.tags)))
        lines.append(subtaskSummary(from: old.subtasks, to: new.subtasks))
        return lines.compactMap { $0 }
    }

    /// «Подзадачи: +2, −1, изменено 1, отмечено 1, снято 1» — только ненулевые части; nil — без изменений.
    static func subtaskSummary(from old: [UUID: SubtaskState], to new: [UUID: SubtaskState]) -> String? {
        let kept = Set(old.keys).intersection(new.keys)
        let counts: [(Int, (Int) -> String)] = [
            (new.keys.filter { old[$0] == nil }.count, { "+\($0)" }),
            (old.keys.filter { new[$0] == nil }.count, { "−\($0)" }),
            (kept.filter { old[$0]?.title != new[$0]?.title }.count, { "изменено \($0)" }),
            (kept.filter { old[$0]?.isDone == false && new[$0]?.isDone == true }.count, { "отмечено \($0)" }),
            (kept.filter { old[$0]?.isDone == true && new[$0]?.isDone == false }.count, { "снято \($0)" }),
        ]
        let parts = counts.filter { $0.0 > 0 }.map { $0.1($0.0) }
        return parts.isEmpty ? nil : "Подзадачи: " + parts.joined(separator: ", ")
    }
}
