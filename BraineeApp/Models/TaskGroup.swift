//
//  TaskGroup.swift
//  BraineeApp
//
//  Модель группы (папки) задач.

import Foundation
import SwiftData

@Model
final class TaskGroup {
    var name: String
    var categoryRaw: String
    var sortOrder: Int
    var createdAt: Date
    var uuid: UUID

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.group)
    var tasks: [TaskItem]?

    init(
        name: String,
        category: TaskCategory = .tasks,
        sortOrder: Int = 0,
        uuid: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.sortOrder = sortOrder
        self.uuid = uuid
        self.createdAt = createdAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .tasks }
        set { categoryRaw = newValue.rawValue }
    }
}
