//
//  TaskTag.swift
//  BraineeApp
//
//  Модель тега из библиотеки тегов в профиле; тег можно прикрепить к задаче.

import Foundation
import SwiftData

@Model
final class TaskTag {
    /// Один uuid — одна запись: повторная вставка обновляет существующую (upsert), а не создаёт дубль (D-17).
    #Unique<TaskTag>([\.uuid])

    var name: String
    var createdAt: Date
    var uuid: UUID
    /// Время последнего изменения (для синхронизации).
    var updatedAt: Date

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]?

    init(name: String, uuid: UUID = UUID(), createdAt: Date = .now, updatedAt: Date? = nil) {
        self.name = name
        self.uuid = uuid
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
