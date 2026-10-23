//
//  Schema.swift
//  BraineeApp
//
//  Версии схемы SwiftData и план миграций. SchemaV1 (SD-1) «заморожена» при появлении SchemaV2 (D-17, D-39).
//  Классы ниже — точная копия моделей из Models/ на момент V1: только хранимые поля, связи и `#Unique`.
//  Их нельзя менять: по ним SwiftData узнаёт старое хранилище и переводит его на V2.
//  Тест `SchemaV2MigrationTests` открывает образец хранилища, созданный сборкой V1.

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            TaskGroup.self,
            TaskTag.self,
            UserProfile.self,
            Habit.self,
        ]
    }
}

extension SchemaV1 {
    @Model
    final class TaskItem {
        #Unique<TaskItem>([\.uuid])

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
        var uuid: UUID
        var isSoftDeleted: Bool
        var deletedAt: Date?
        var updatedAt: Date
        var completedAt: Date?

        var group: TaskGroup?

        @Relationship
        var tags: [TaskTag]

        /// Только для тестов миграции: записи V1 создаются напрямую, без правил новой модели.
        init(
            title: String,
            isCompleted: Bool = false,
            deadline: Date? = nil,
            hasDeadlineTime: Bool = false,
            reminderOffsetsRaw: [String] = [],
            priorityRaw: Int = TaskPriority.medium.rawValue,
            categoryRaw: String = TaskCategory.tasks.rawValue,
            statusRaw: String = TaskStatus.new.rawValue,
            createdAt: Date = .now,
            taskDetails: String = "",
            sortOrder: Int = 0,
            uuid: UUID = UUID(),
            isSoftDeleted: Bool = false,
            deletedAt: Date? = nil,
            updatedAt: Date? = nil,
            completedAt: Date? = nil,
            group: TaskGroup? = nil,
            tags: [TaskTag] = []
        ) {
            self.title = title
            self.isCompleted = isCompleted
            self.deadline = deadline
            self.hasDeadlineTime = hasDeadlineTime
            self.reminderOffsetsRaw = reminderOffsetsRaw
            self.priorityRaw = priorityRaw
            self.categoryRaw = categoryRaw
            self.statusRaw = statusRaw
            self.createdAt = createdAt
            self.taskDetails = taskDetails
            self.sortOrder = sortOrder
            self.uuid = uuid
            self.isSoftDeleted = isSoftDeleted
            self.deletedAt = deletedAt
            self.updatedAt = updatedAt ?? createdAt
            self.completedAt = completedAt
            self.group = group
            self.tags = tags
        }
    }

    @Model
    final class TaskGroup {
        #Unique<TaskGroup>([\.uuid])

        var name: String
        var categoryRaw: String
        var sortOrder: Int
        var createdAt: Date
        var uuid: UUID
        var updatedAt: Date

        @Relationship(deleteRule: .nullify, inverse: \TaskItem.group)
        var tasks: [TaskItem]?

        init(name: String, sortOrder: Int = 0, uuid: UUID = UUID(), createdAt: Date = .now, updatedAt: Date? = nil) {
            self.name = name
            self.categoryRaw = TaskCategory.tasks.rawValue
            self.sortOrder = sortOrder
            self.uuid = uuid
            self.createdAt = createdAt
            self.updatedAt = updatedAt ?? createdAt
        }
    }

    @Model
    final class TaskTag {
        #Unique<TaskTag>([\.uuid])

        var name: String
        var createdAt: Date
        var uuid: UUID
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

    @Model
    final class UserProfile {
        #Unique<UserProfile>([\.uuid])

        var uuid: UUID
        var displayName: String
        var avatarData: Data?
        var age: Int?
        var genderRaw: String
        var createdAt: Date

        init(
            uuid: UUID = UUID(),
            displayName: String = "",
            avatarData: Data? = nil,
            age: Int? = nil,
            genderRaw: String = UserGender.unspecified.rawValue,
            createdAt: Date = .now
        ) {
            self.uuid = uuid
            self.displayName = displayName
            self.avatarData = avatarData
            self.age = age
            self.genderRaw = genderRaw
            self.createdAt = createdAt
        }
    }

    @Model
    final class Habit {
        #Unique<Habit>([\.uuid])

        var title: String
        var sortOrder: Int
        var uuid: UUID
        var createdAt: Date
        var updatedAt: Date
        var completedDaysRaw: String

        init(
            title: String,
            sortOrder: Int = 0,
            uuid: UUID = UUID(),
            createdAt: Date = .now,
            updatedAt: Date? = nil,
            completedDaysRaw: String = "[]"
        ) {
            self.title = title
            self.sortOrder = sortOrder
            self.uuid = uuid
            self.createdAt = createdAt
            self.updatedAt = updatedAt ?? createdAt
            self.completedDaysRaw = completedDaysRaw
        }
    }
}

/// Вторая версия (D-39): у задачи — длительность (`durationMinutes`) и подзадачи (`TaskSubtask`).
/// Ссылается на текущие классы из Models/; при SchemaV3 её нужно заморозить так же, как V1.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            TaskGroup.self,
            TaskTag.self,
            UserProfile.self,
            Habit.self,
            TaskSubtask.self,
        ]
    }
}

/// План миграций постоянного хранилища. V1 → V2 только добавляет необязательное поле и новую сущность,
/// поэтому этап лёгкий: существующие записи не переписываются. Страховка — `SchemaUpgrade`.
enum BraineeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

/// Текущая версия схемы — менять здесь при добавлении новой версии.
typealias CurrentSchema = SchemaV2
