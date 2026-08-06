//
//  TaskDragID.swift
//  BraineeApp
//

import Foundation
import SwiftData

extension TaskItem {
    static func fetch(byUUID uuid: UUID, in context: ModelContext) -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try? context.fetch(descriptor).first
    }
}

enum TaskDragPayload {
    static func task(in tasks: [TaskItem], from payload: [String]) -> TaskItem? {
        guard let raw = payload.first,
              let uuid = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return tasks.first(where: { $0.uuid == uuid && !$0.isDeleted })
    }
}
