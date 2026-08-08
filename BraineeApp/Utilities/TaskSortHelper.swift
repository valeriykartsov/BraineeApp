//
//  TaskSortHelper.swift
//  BraineeApp
//
//  Правила сортировки задач в списке: незакрытые сверху, внутри — по дате/порядку.

import Foundation

enum TaskSortHelper {
    /// Выполненные всегда внизу; среди активных — просроченные/даты/приоритет/порядок.
    static func byListMode(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }
        if lhs.isCompleted {
            return lhs.sortOrder < rhs.sortOrder
        }
        let lhsRank = dateRank(for: lhs)
        let rhsRank = dateRank(for: rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    /// Совместимость со старыми тестами «по дате» (без учёта выполнения в приоритете даты).
    static func byDateMode(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        byListMode(lhs, rhs)
    }

    static func byDayPlan(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    /// Переносит задачу в конец своей группы (или «без папки»).
    static func moveToEnd(of peers: [TaskItem], task: TaskItem) {
        let others = peers.filter { $0.uuid != task.uuid }
        let maxOrder = others.map(\.sortOrder).max() ?? -1
        task.sortOrder = maxOrder + 1
    }

    /// Чем меньше число, тем выше задача среди незакрытых.
    private static func dateRank(for task: TaskItem) -> Int {
        if task.isOverdue { return 0 }
        guard let deadline = task.deadline else { return 4 }
        let calendar = Calendar.current
        if calendar.isDateInToday(deadline) { return 1 }
        if calendar.isDateInTomorrow(deadline) { return 2 }
        return 3
    }
}
