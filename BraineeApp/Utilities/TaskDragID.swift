//
//  TaskDragID.swift
//  BraineeApp
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

struct TaskDragID: Transferable, Codable {
    let uuid: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .braineeTaskDrag)
    }
}

extension UTType {
    static let braineeTaskDrag = UTType(exportedAs: "valeravalera.braineeapp.task-drag")
}

extension TaskItem {
    static func fetch(byUUID uuid: UUID, in context: ModelContext) -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try? context.fetch(descriptor).first
    }
}
