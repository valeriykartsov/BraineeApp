//
//  AppDataDocuments.swift
//  BraineeApp
//
//  Структуры JSON-файлов: как задачи, группы и профиль выглядят на диске.

import Foundation

/// Корневой документ mytasks.json — задачи, группы, теги и привычки.
struct MyTasksDocument: Codable {
    var version: Int
    var lastSavedAt: Date?
    var tags: [TagRecord]
    var groups: [GroupRecord]
    var tasks: [TaskRecord]
    var habits: [HabitRecord]

    static let currentVersion = 8
    static let empty = MyTasksDocument(
        version: currentVersion,
        lastSavedAt: nil,
        tags: [],
        groups: [],
        tasks: [],
        habits: []
    )

    init(
        version: Int,
        lastSavedAt: Date?,
        tags: [TagRecord],
        groups: [GroupRecord],
        tasks: [TaskRecord],
        habits: [HabitRecord] = []
    ) {
        self.version = version
        self.lastSavedAt = lastSavedAt
        self.tags = tags
        self.groups = groups
        self.tasks = tasks
        self.habits = habits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastSavedAt = try container.decodeIfPresent(Date.self, forKey: .lastSavedAt)
        tags = try container.decodeIfPresent([TagRecord].self, forKey: .tags) ?? []
        groups = try container.decodeIfPresent([GroupRecord].self, forKey: .groups) ?? []
        tasks = try container.decodeIfPresent([TaskRecord].self, forKey: .tasks) ?? []
        habits = try container.decodeIfPresent([HabitRecord].self, forKey: .habits) ?? []
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

        var seenHabitIDs = Set<UUID>()
        habits = habits.filter { record in
            guard seenHabitIDs.insert(record.id).inserted else { return false }
            return true
        }
        // Не больше 7 привычек — лишние отбрасываем (порядок sortOrder).
        habits.sort { $0.sortOrder < $1.sortOrder }
        if habits.count > Habit.maxCount {
            habits = Array(habits.prefix(Habit.maxCount))
        }

        let validGroupIDs = Set(groups.map(\.id))
        let validTagIDs = Set(tags.map(\.id))

        // v3: все разделы (career/sport/mental) сливаются в единый «Задачи».
        for index in groups.indices {
            groups[index].categoryRaw = TaskCategory.unifiedRaw
        }

        for index in tasks.indices {
            if tasks[index].isDeleted && tasks[index].deletedAt == nil {
                tasks[index].deletedAt = tasks[index].createdAt
            }

            if let groupID = tasks[index].groupID, !validGroupIDs.contains(groupID) {
                tasks[index].groupID = nil
            }

            tasks[index].tagIDs = tasks[index].tagIDs.filter { validTagIDs.contains($0) }
            tasks[index].categoryRaw = TaskCategory.unifiedRaw

            // v5: статус + согласованность с isCompleted.
            let status = TaskStatus(rawValue: tasks[index].statusRaw)
                ?? TaskStatus.fromCompletion(tasks[index].isCompleted)
            tasks[index].statusRaw = status.rawValue
            tasks[index].isCompleted = status == .done

            // v6: время дедлайна только если дата задана.
            if tasks[index].deadline == nil {
                tasks[index].hasDeadlineTime = false
                tasks[index].reminderOffsetsRaw = []
            }

            // v8: до 3 пресетов напоминаний (как в Calendar).
            tasks[index].reminderOffsetsRaw = TaskReminderOffset
                .normalizedList(tasks[index].reminderOffsetsRaw)
                .map(\.rawValue)
        }

        for index in habits.indices {
            habits[index].completedDays = Array(Set(habits[index].completedDays)).sorted()
            habits[index].title = habits[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        habits.removeAll { $0.title.isEmpty }
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
    var hasDeadlineTime: Bool
    var reminderOffsetsRaw: [String]
    var priorityRaw: Int
    var categoryRaw: String
    var statusRaw: String
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
        hasDeadlineTime: Bool = false,
        reminderOffsetsRaw: [String] = [],
        priorityRaw: Int,
        categoryRaw: String,
        statusRaw: String = TaskStatus.new.rawValue,
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
        self.hasDeadlineTime = hasDeadlineTime && deadline != nil
        self.reminderOffsetsRaw = deadline == nil
            ? []
            : TaskReminderOffset.encodeList(
                TaskReminderOffset.normalizedList(reminderOffsetsRaw)
            )
        self.priorityRaw = priorityRaw
        self.categoryRaw = categoryRaw
        self.statusRaw = statusRaw
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
        hasDeadlineTime = (try container.decodeIfPresent(Bool.self, forKey: .hasDeadlineTime) ?? false)
            && deadline != nil

        if let offsets = try container.decodeIfPresent([String].self, forKey: .reminderOffsetsRaw) {
            reminderOffsetsRaw = TaskReminderOffset.encodeList(
                TaskReminderOffset.normalizedList(offsets)
            )
        } else {
            // v7 → v8: одно напоминание value + unit.
            let legacyOn = (try container.decodeIfPresent(Bool.self, forKey: .hasReminder) ?? false)
                && deadline != nil
            let legacyValue = try container.decodeIfPresent(Int.self, forKey: .reminderValue) ?? 1
            let legacyUnit = try container.decodeIfPresent(String.self, forKey: .reminderUnitRaw) ?? "hours"
            if legacyOn, let offset = TaskReminderOffset.migrated(fromValue: legacyValue, unitRaw: legacyUnit) {
                reminderOffsetsRaw = [offset.rawValue]
            } else {
                reminderOffsetsRaw = []
            }
        }
        if deadline == nil {
            reminderOffsetsRaw = []
        }

        priorityRaw = try container.decodeIfPresent(Int.self, forKey: .priorityRaw) ?? TaskPriority.medium.rawValue
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? TaskCategory.unifiedRaw
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        taskDetails = try container.decodeIfPresent(String.self, forKey: .taskDetails) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        if let raw = try container.decodeIfPresent(String.self, forKey: .statusRaw),
           TaskStatus(rawValue: raw) != nil {
            statusRaw = raw
        } else {
            statusRaw = TaskStatus.fromCompletion(isCompleted).rawValue
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, deadline, hasDeadlineTime
        case reminderOffsetsRaw
        case hasReminder, reminderValue, reminderUnitRaw // только decode (миграция v7)
        case priorityRaw, categoryRaw, statusRaw, createdAt, taskDetails
        case sortOrder, groupID, tagIDs, isDeleted, deletedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encode(hasDeadlineTime, forKey: .hasDeadlineTime)
        try container.encode(reminderOffsetsRaw, forKey: .reminderOffsetsRaw)
        try container.encode(priorityRaw, forKey: .priorityRaw)
        try container.encode(categoryRaw, forKey: .categoryRaw)
        try container.encode(statusRaw, forKey: .statusRaw)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(taskDetails, forKey: .taskDetails)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encode(tagIDs, forKey: .tagIDs)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
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
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? TaskCategory.unifiedRaw
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

/// Привычка в JSON.
struct HabitRecord: Codable, Identifiable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var completedDays: [String]

    init(
        id: UUID,
        title: String,
        sortOrder: Int,
        createdAt: Date,
        completedDays: [String] = []
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedDays = completedDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        completedDays = try container.decodeIfPresent([String].self, forKey: .completedDays) ?? []
    }
}

/// Файл profile.json — имя, аватар, возраст, пол и тема оформления.
struct ProfileDocument: Codable {
    var version: Int
    var displayName: String
    var avatarBase64: String?
    var age: Int?
    var genderRaw: String
    var appThemeRaw: String
    var accentPaletteRaw: String
    var createdAt: Date

    static let currentVersion = 3

    static let empty = ProfileDocument(
        version: currentVersion,
        displayName: "",
        avatarBase64: nil,
        age: nil,
        genderRaw: UserGender.unspecified.rawValue,
        appThemeRaw: AppTheme.system.rawValue,
        accentPaletteRaw: AccentPalette.orange.rawValue,
        createdAt: .now
    )

    init(
        version: Int,
        displayName: String,
        avatarBase64: String?,
        age: Int?,
        genderRaw: String,
        appThemeRaw: String,
        accentPaletteRaw: String,
        createdAt: Date
    ) {
        self.version = version
        self.displayName = displayName
        self.avatarBase64 = avatarBase64
        self.age = age
        self.genderRaw = genderRaw
        self.appThemeRaw = appThemeRaw
        self.accentPaletteRaw = accentPaletteRaw
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarBase64 = try container.decodeIfPresent(String.self, forKey: .avatarBase64)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        genderRaw = try container.decodeIfPresent(String.self, forKey: .genderRaw)
            ?? UserGender.unspecified.rawValue
        appThemeRaw = try container.decodeIfPresent(String.self, forKey: .appThemeRaw)
            ?? AppTheme.system.rawValue
        accentPaletteRaw = try container.decodeIfPresent(String.self, forKey: .accentPaletteRaw)
            ?? AccentPalette.orange.rawValue
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    /// Нормализация старых profile.json и граничных значений.
    mutating func normalize() {
        version = Self.currentVersion
        displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if UserGender(rawValue: genderRaw) == nil {
            genderRaw = UserGender.unspecified.rawValue
        }
        if AccentPalette(rawValue: accentPaletteRaw) == nil {
            accentPaletteRaw = AccentPalette.orange.rawValue
        }
        if let age, (age < 1 || age > 120) {
            self.age = nil
        }
    }
}
