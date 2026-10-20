//
//  CalendarEventRules.swift
//  BraineeApp
//
//  Правила экспорта задачи в событие календаря (roadmap CAL-2, D-06, D-22) — чистые функции
//  без EventKit, чтобы их можно было проверить тестами.

import Foundation

/// Каким должно быть событие календаря для задачи (или каким его прочитали из календаря).
struct CalendarEventDraft: Equatable {
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var notes: String?
    /// Метка `braineeapp://task/<uuid>`: по ней событие находится, если связь потеряна (D-22).
    var url: URL?
}

enum CalendarEventRules {
    /// Задача со временем занимает слот 30 минут (D-06).
    static let timedDuration: TimeInterval = 30 * 60
    static let calendarTitle = "BraineeApp"
    private static let urlScheme = "braineeapp"
    private static let urlHost = "task"

    static func url(for taskUUID: UUID) -> URL {
        URL(string: "\(urlScheme)://\(urlHost)/\(taskUUID.uuidString)")!
    }

    /// uuid задачи из метки события; nil — событие создано не экспортом задач.
    static func taskUUID(from url: URL?) -> UUID? {
        guard let url, url.scheme == urlScheme, url.host == urlHost else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    /// Событие для задачи. nil — задача не экспортируется: нет даты, выполнена или удалена (D-06).
    static func draft(
        title: String,
        deadline: Date?,
        hasDeadlineTime: Bool,
        isDone: Bool,
        isSoftDeleted: Bool,
        details: String,
        uuid: UUID,
        calendar: Calendar = .current
    ) -> CalendarEventDraft? {
        guard let deadline, !isDone, !isSoftDeleted else { return nil }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let start: Date
        let end: Date
        if hasDeadlineTime {
            start = deadline
            end = deadline.addingTimeInterval(timedDuration)
        } else {
            start = calendar.startOfDay(for: deadline)
            end = start
        }
        return CalendarEventDraft(
            title: trimmedTitle.isEmpty ? "Без названия" : trimmedTitle,
            start: start,
            end: end,
            isAllDay: !hasDeadlineTime,
            notes: trimmedDetails.isEmpty ? nil : trimmedDetails,
            url: url(for: uuid)
        )
    }

    @MainActor
    static func draft(for task: TaskItem, calendar: Calendar = .current) -> CalendarEventDraft? {
        draft(
            title: task.title,
            deadline: task.deadline,
            hasDeadlineTime: task.hasDeadlineTime,
            isDone: task.status == .done,
            isSoftDeleted: task.isSoftDeleted,
            details: task.taskDetails,
            uuid: task.uuid,
            calendar: calendar
        )
    }

    /// Нужно ли переписывать событие. Сравнение «по смыслу»: у события на весь день EventKit
    /// возвращает конец дня как конец события, поэтому для него сравнивается только день начала.
    /// Без этого каждое изменение данных заново сохраняло бы все события.
    static func needsUpdate(
        _ existing: CalendarEventDraft,
        to draft: CalendarEventDraft,
        calendar: Calendar = .current
    ) -> Bool {
        guard existing.title == draft.title,
              existing.isAllDay == draft.isAllDay,
              (existing.notes ?? "") == (draft.notes ?? ""),
              existing.url == draft.url
        else { return true }
        if draft.isAllDay {
            return !calendar.isDate(existing.start, inSameDayAs: draft.start)
        }
        return abs(existing.start.timeIntervalSince(draft.start)) >= 1
            || abs(existing.end.timeIntervalSince(draft.end)) >= 1
    }
}
