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

    init(
        title: String,
        isCompleted: Bool = false,
        deadline: Date? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory,
        createdAt: Date = .now
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
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
