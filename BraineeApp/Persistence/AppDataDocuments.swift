//
//  AppDataDocuments.swift
//  BraineeApp
//
//  Структуры JSON-файлов: как задачи, группы и профиль выглядят на диске.

import Foundation

/// Корневой документ mytasks.json — все задачи, группы и теги приложения.
struct MyTasksDocument: Codable {
    var version: Int
    var lastSavedAt: Date?
    var tags: [TagRecord]
    var groups: [GroupRecord]
    var tasks: [TaskRecord]

    static let currentVersion = 2
    static let empty = MyTasksDocument(
        version: currentVersion,
        lastSavedAt: nil,
        tags: [],
        groups: [],
        tasks: []
    )

    init(
        version: Int,
        lastSavedAt: Date?,
        tags: [TagRecord],
        groups: [GroupRecord],
        tasks: [TaskRecord]
    ) {
        self.version = version
        self.lastSavedAt = lastSavedAt
        self.tags = tags
        self.groups = groups
        self.tasks = tasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastSavedAt = try container.decodeIfPresent(Date.self, forKey: .lastSavedAt)
        tags = try container.decodeIfPresent([TagRecord].self, forKey: .tags) ?? []
        groups = try container.decodeIfPresent([GroupRecord].self, forKey: .groups) ?? []
        tasks = try container.decodeIfPresent([TaskRecord].self, forKey: .tasks) ?? []
    }

    /// Чинит старые файлы: убирает дубликаты и битые ссылки на группы/теги.
    mutating func normalizeRecords() {
        version = Self.currentVersion

        var seenTaskIDs = Set<UUID>()
        tasks = tasks.filter { record in
            guard seenTaskIDs.insert(record.id).inserted else { return false }
            return true
        }

        var seenGroupIDs = Set<UUID>()
        groups = groups.filter { record in
            guard seenGroupIDs.insert(record.id).inserted else { return false }
            return true
        }

        var seenTagIDs = Set<UUID>()
        tags = tags.filter { record in
            guard seenTagIDs.insert(record.id).inserted else { return false }
            return true
        }

        let validGroupIDs = Set(groups.map(\.id))
        let validTagIDs = Set(tags.map(\.id))

        for index in tasks.indices {
            if tasks[index].isDeleted && tasks[index].deletedAt == nil {
                tasks[index].deletedAt = tasks[index].createdAt
            }

            if let groupID = tasks[index].groupID, !validGroupIDs.contains(groupID) {
                tasks[index].groupID = nil
            }

            tasks[index].tagIDs = tasks[index].tagIDs.filter { validTagIDs.contains($0) }
        }
    }

    /// Помогает выбрать более свежую копию между файлом и Keychain.
    var contentTimestamp: Date {
        lastSavedAt ?? tasks.map(\.createdAt).max() ?? .distantPast
    }
}

/// Одна задача в JSON (зеркало полей TaskItem).
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
    var isDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID,
        title: String,
        isCompleted: Bool,
        deadline: Date?,
        priorityRaw: Int,
        categoryRaw: String,
        createdAt: Date,
        taskDetails: String,
        sortOrder: Int,
        groupID: UUID?,
        tagIDs: [UUID],
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.priorityRaw = priorityRaw
        self.categoryRaw = categoryRaw
        self.createdAt = createdAt
        self.taskDetails = taskDetails
        self.sortOrder = sortOrder
        self.groupID = groupID
        self.tagIDs = tagIDs
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    /// Старые JSON без новых полей читаются с безопасными значениями по умолчанию.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        priorityRaw = try container.decodeIfPresent(Int.self, forKey: .priorityRaw) ?? TaskPriority.medium.rawValue
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? TaskCategory.career.rawValue
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        taskDetails = try container.decodeIfPresent(String.self, forKey: .taskDetails) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

/// Группа задач в JSON.
struct GroupRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var categoryRaw: String
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID, name: String, categoryRaw: String, sortOrder: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.categoryRaw = categoryRaw
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Группа"
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? TaskCategory.career.rawValue
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}

/// Тег в JSON.
struct TagRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Тег"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}

/// Файл profile.json — имя, аватар и тема оформления.
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
