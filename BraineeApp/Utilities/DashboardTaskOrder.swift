//
//  DashboardTaskOrder.swift
//  BraineeApp
//
//  Порядок задач в группах подробностей дашборда (по приоритетам и тегам, п. 42):
//  актуальные (новые, в работе) → выполненные → в корзине; внутри части — по названию.

import Foundation

enum DashboardTaskOrder {
    /// Часть списка: чем меньше, тем выше.
    static func rank(of task: TaskItem) -> Int {
        if task.isSoftDeleted { return 2 }
        return task.isCompleted ? 1 : 0
    }

    static func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            let left = rank(of: lhs)
            let right = rank(of: rhs)
            if left != right { return left < right }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
