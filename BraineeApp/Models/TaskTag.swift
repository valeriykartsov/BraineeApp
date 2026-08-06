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
    var uuid: UUID

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]?

    init(name: String, uuid: UUID = UUID(), createdAt: Date = .now) {
        self.name = name
        self.uuid = uuid
        self.createdAt = createdAt
    }
}
