//
//  TaskDragID.swift
//  BraineeApp
//
//  Помощники для drag-and-drop: поиск задачи по UUID из перетаскиваемой строки.

import Foundation
import SwiftData

extension TaskItem {
    /// Находит задачу в SwiftData по стабильному UUID (не по id строки списка).
    static func fetch(byUUID uuid: UUID, in context: ModelContext) -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try? context.fetch(descriptor).first
    }
}

enum TaskDragPayload {
    /// Превращает строку из drop-жеста обратно в задачу из переданного списка.
    static func task(in tasks: [TaskItem], from payload: [String]) -> TaskItem? {
        guard let raw = payload.first,
              let uuid = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return tasks.first(where: { $0.uuid == uuid && !$0.isDeleted })
    }
}
