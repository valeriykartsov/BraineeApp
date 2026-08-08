//
//  EisenhowerQuadrant.swift
//  BraineeApp
//
//  Матрица Эйзенхауэра: срочность по дедлайну (≤2 дня / просрочка), важность по приоритету.

import Foundation

enum EisenhowerQuadrant: String, CaseIterable, Identifiable {
    case doFirst
    case schedule
    case delegate
    case eliminate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doFirst: "Сделать"
        case .schedule: "Запланировать"
        case .delegate: "Делегировать"
        case .eliminate: "Убрать"
        }
    }

    var subtitle: String {
        switch self {
        case .doFirst: "Важно и срочно"
        case .schedule: "Важно, не срочно"
        case .delegate: "Не важно, срочно"
        case .eliminate: "Не важно, не срочно"
        }
    }

    /// Порог срочности: сегодня и ещё 2 календарных дня.
    static let urgentDayLimit = 2

    /// Классификация по дедлайну и приоритету (правила 2A из плана).
    static func classify(
        deadline: Date?,
        priority: TaskPriority,
        isCompleted: Bool = false,
        hasDeadlineTime: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> EisenhowerQuadrant {
        let isImportant = priority == .high || priority == .highest
        let isUrgent = Self.isUrgent(
            deadline: deadline,
            hasDeadlineTime: hasDeadlineTime,
            isCompleted: isCompleted,
            now: now,
            calendar: calendar
        )

        switch (isImportant, isUrgent) {
        case (true, true): return .doFirst
        case (true, false): return .schedule
        case (false, true): return .delegate
        case (false, false): return .eliminate
        }
    }

    static func classify(_ task: TaskItem, now: Date = .now, calendar: Calendar = .current) -> EisenhowerQuadrant {
        classify(
            deadline: task.deadline,
            priority: task.priority,
            isCompleted: task.isCompleted,
            hasDeadlineTime: task.hasDeadlineTime,
            now: now,
            calendar: calendar
        )
    }

    /// Срочно: просрочено (дата или дата+время) или дедлайн в пределах сегодня…+2 дня. Без дедлайна — не срочно.
    static func isUrgent(
        deadline: Date?,
        hasDeadlineTime: Bool = false,
        isCompleted: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let deadline else { return false }
        let today = calendar.startOfDay(for: now)
        let deadlineDay = calendar.startOfDay(for: deadline)

        if !isCompleted {
            if hasDeadlineTime {
                if deadline < now { return true }
            } else if deadlineDay < today {
                return true
            }
        }

        guard let urgentEnd = calendar.date(byAdding: .day, value: urgentDayLimit, to: today) else {
            return false
        }
        return deadlineDay >= today && deadlineDay <= urgentEnd
    }
}
