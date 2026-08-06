//
//  TaskGroup.swift
//  BraineeApp
//

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
        category: TaskCategory,
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
        get { TaskCategory(rawValue: categoryRaw) ?? .career }
        set { categoryRaw = newValue.rawValue }
    }
}
