//
//  TaskSortHelper.swift
//  BraineeApp
//
//  Правила сортировки задач для режимов «По дате» и «План на день».

import Foundation

enum TaskSortHelper {
    /// Сначала просроченные, затем сегодня, завтра, остальные; внутри — по приоритету.
    static func byDateMode(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let lhsRank = dateRank(for: lhs)
        let rhsRank = dateRank(for: rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    /// Активные задачи выше выполненных, затем по приоритету и порядку в списке.
    static func byDayPlan(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    /// Чем меньше число, тем выше задача в списке «По дате».
    private static func dateRank(for task: TaskItem) -> Int {
        if task.isOverdue { return 0 }
        guard let deadline = task.deadline else { return 4 }
        let calendar = Calendar.current
        if calendar.isDateInToday(deadline) { return 1 }
        if calendar.isDateInTomorrow(deadline) { return 2 }
        return 3
    }
}
