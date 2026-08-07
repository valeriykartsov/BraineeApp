//
//  TaskItem.swift
//  BraineeApp
//
//  Модель задачи: название, дедлайн, приоритет, описание, группа, теги и мягкое удаление.

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

    /// Просрочена, если дедлайн был раньше сегодня и задача не выполнена.
    var isOverdue: Bool {
        guard let deadline, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: deadline) < Calendar.current.startOfDay(for: .now)
    }

    var isDueToday: Bool {
        guard let deadline else { return false }
        return Calendar.current.isDateInToday(deadline)
    }
}
