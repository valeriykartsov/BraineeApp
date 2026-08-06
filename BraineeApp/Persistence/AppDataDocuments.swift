//
//  AppDataDocuments.swift
//  BraineeApp
//

import Foundation

struct MyTasksDocument: Codable {
    var version: Int
    var tags: [TagRecord]
    var groups: [GroupRecord]
    var tasks: [TaskRecord]

    static let empty = MyTasksDocument(version: 1, tags: [], groups: [], tasks: [])
}

struct TaskRecord: Codable, Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var deadline: Date?
    var priorityRaw: Int
    var categoryRaw: String
    var createdAt: Date
    var taskDetails: String
    var sortOrder: Int
    var groupID: UUID?
    var tagIDs: [UUID]
}

struct GroupRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var categoryRaw: String
    var sortOrder: Int
    var createdAt: Date
}

struct TagRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
}

struct ProfileDocument: Codable {
    var version: Int
    var displayName: String
    var avatarBase64: String?
    var appThemeRaw: String
    var createdAt: Date

    static let empty = ProfileDocument(
        version: 1,
        displayName: "",
        avatarBase64: nil,
        appThemeRaw: AppTheme.system.rawValue,
        createdAt: .now
    )
}
