//
//  TaskTag.swift
//  BraineeApp
//

import Foundation
import SwiftData

@Model
final class TaskTag {
    var name: String
    var createdAt: Date

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]?

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
