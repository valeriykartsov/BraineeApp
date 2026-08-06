//
//  TaskItem.swift
//  BraineeApp
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var isCompleted: Bool
    var deadline: Date?
    var priorityRaw: Int
    var categoryRaw: String
    var createdAt: Date
    var taskDetails: String
    var sortOrder: Int
    var uuid: UUID
    var isDeleted: Bool
    var deletedAt: Date?

    var group: TaskGroup?

    @Relationship
    var tags: [TaskTag]

    init(
        title: String,
        isCompleted: Bool = false,
        deadline: Date? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory,
        createdAt: Date = .now,
        taskDetails: String = "",
        sortOrder: Int = 0,
        uuid: UUID = UUID(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        group: TaskGroup? = nil,
        tags: [TaskTag] = []
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
        self.taskDetails = taskDetails
        self.sortOrder = sortOrder
        self.uuid = uuid
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.group = group
        self.tags = tags
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .career }
        set { categoryRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let deadline, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: deadline) < Calendar.current.startOfDay(for: .now)
    }

    var isDueToday: Bool {
        guard let deadline else { return false }
        return Calendar.current.isDateInToday(deadline)
    }
}

enum TaskSortHelper {
    static func byDateMode(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let lhsRank = dateRank(for: lhs)
        let rhsRank = dateRank(for: rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    static func byDayPlan(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.sortOrder < rhs.sortOrder
    }

    private static func dateRank(for task: TaskItem) -> Int {
        if task.isOverdue { return 0 }
        guard let deadline = task.deadline else { return 4 }
        let calendar = Calendar.current
        if calendar.isDateInToday(deadline) { return 1 }
        if calendar.isDateInTomorrow(deadline) { return 2 }
        return 3
    }
}
