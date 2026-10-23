//
//  AppDataPersistence.swift
//  BraineeApp
//
//  Загрузка при старте и связь SwiftData с JSON-документами бэкапа (экспорт и импорт записей).

import Foundation
import SwiftData
import SwiftUI

enum AppDataPersistence {
    /// Загрузка при запуске. Данные живут в постоянном хранилище SwiftData и при старте
    /// не очищаются и не перезаписываются (R1). Устаревшие JSON и Keychain-копии удаляются
    /// после завершённого переноса (SD-6); ошибка очистки не мешает запуску.
    @MainActor
    static func bootstrap(
        into context: ModelContext,
        cleanup: LegacyStorageCleanup = .standard,
        defaults: UserDefaults = .standard
    ) {
        applyAccentDefaults(defaults: defaults)

        do {
            let result = try cleanup.run()
            if !result.removedFiles.isEmpty || !result.removedKeychainItems.isEmpty {
                print("LegacyStorageCleanup: files \(result.removedFiles), keychain \(result.removedKeychainItems)")
            }
        } catch {
            print("LegacyStorageCleanup failed: \(error)")
        }

        WidgetSnapshotBuilder.publish(
            tasks: context.fetchActiveTasks(),
            habits: context.fetchHabits()
        )
    }

    /// Первая установка / переустановка (нет маркера запуска) → оранжевый акцент + маркер.
    /// Повторный запуск не трогает выбранный акцент.
    static func applyAccentDefaults(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: AccentPalette.hasLaunchedStorageKey) else { return }
        defaults.set(AccentPalette.orange.rawValue, forKey: AccentPalette.storageKey)
        defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
    }

    // Используется восстановлением из бэкапа (StoreContents); round-trip — в AppDataPersistenceRoundTripTests.
    static func importTasks(_ document: MyTasksDocument, into context: ModelContext) {
        var tagByID: [UUID: TaskTag] = [:]
        for record in document.tags {
            let tag = TaskTag(
                name: record.name,
                uuid: record.id,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(tag)
            tagByID[record.id] = tag
        }

        var groupByID: [UUID: TaskGroup] = [:]
        for record in document.groups {
            let group = TaskGroup(
                name: record.name,
                category: .tasks,
                sortOrder: record.sortOrder,
                uuid: record.id,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(group)
            groupByID[record.id] = group
        }

        for record in document.tasks {
            let tags = record.tagIDs.compactMap { tagByID[$0] }
            let status = TaskStatus(rawValue: record.statusRaw)
                ?? TaskStatus.fromCompletion(record.isCompleted)
            let task = TaskItem(
                title: record.title,
                isCompleted: status == .done,
                deadline: record.deadline,
                hasDeadlineTime: record.hasDeadlineTime,
                reminderOffsets: TaskReminderOffset.normalizedList(record.reminderOffsetsRaw),
                priority: TaskPriority(rawValue: record.priorityRaw) ?? .medium,
                category: .tasks,
                status: status,
                createdAt: record.createdAt,
                taskDetails: record.taskDetails,
                sortOrder: record.sortOrder,
                uuid: record.id,
                isSoftDeleted: record.isDeleted,
                deletedAt: record.deletedAt ?? (record.isDeleted ? record.createdAt : nil),
                updatedAt: record.updatedAt,
                completedAt: record.completedAt,
                durationMinutes: record.durationMinutes,
                group: record.groupID.flatMap { groupByID[$0] },
                tags: tags,
                subtasks: record.subtasks.map {
                    TaskSubtask(uuid: $0.id, title: $0.title, isDone: $0.isDone, sortOrder: $0.sortOrder)
                }
            )
            context.insert(task)
        }

        for record in document.habits {
            let habit = Habit(
                title: record.title,
                sortOrder: record.sortOrder,
                uuid: record.id,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                completedDayKeys: record.completedDays
            )
            context.insert(habit)
        }
    }

    static func importProfile(_ document: ProfileDocument, into context: ModelContext) {
        var normalized = document
        normalized.normalize()
        let avatarData = normalized.avatarBase64.flatMap { Data(base64Encoded: $0) }
        let profile = UserProfile(
            uuid: normalized.id ?? UUID(),
            displayName: normalized.displayName,
            avatarData: avatarData,
            age: normalized.age,
            gender: UserGender.resolved(from: normalized.genderRaw),
            createdAt: normalized.createdAt
        )
        context.insert(profile)
    }

    static func exportTasks(from context: ModelContext) -> MyTasksDocument {
        let tags = (try? context.fetch(FetchDescriptor<TaskTag>())) ?? []
        let groups = (try? context.fetch(FetchDescriptor<TaskGroup>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []

        return MyTasksDocument(
            version: MyTasksDocument.currentVersion,
            lastSavedAt: .now,
            tags: tags.map {
                TagRecord(id: $0.uuid, name: $0.name, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            groups: groups.map {
                GroupRecord(
                    id: $0.uuid,
                    name: $0.name,
                    categoryRaw: $0.categoryRaw,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            tasks: tasks.map {
                TaskRecord(
                    id: $0.uuid,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    deadline: $0.deadline,
                    hasDeadlineTime: $0.hasDeadlineTime,
                    reminderOffsetsRaw: $0.reminderOffsetsRaw,
                    priorityRaw: $0.priorityRaw,
                    categoryRaw: $0.categoryRaw,
                    statusRaw: $0.statusRaw,
                    createdAt: $0.createdAt,
                    taskDetails: $0.taskDetails,
                    sortOrder: $0.sortOrder,
                    groupID: $0.group?.uuid,
                    tagIDs: $0.tags.map(\.uuid),
                    isDeleted: $0.isSoftDeleted,
                    // Без даты удаления — время изменения: экспорт одного и того же хранилища
                    // должен давать одинаковый результат (сверка при переходе на V2, D-39).
                    deletedAt: $0.isSoftDeleted ? ($0.deletedAt ?? $0.updatedAt) : nil,
                    updatedAt: $0.updatedAt,
                    completedAt: $0.completedAt,
                    durationMinutes: $0.durationMinutes,
                    subtasks: $0.sortedSubtasks.map {
                        SubtaskRecord(id: $0.uuid, title: $0.title, isDone: $0.isDone, sortOrder: $0.sortOrder)
                    }
                )
            },
            habits: habits.map {
                HabitRecord(
                    id: $0.uuid,
                    title: $0.title,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt,
                    completedDays: $0.completedDayKeys,
                    updatedAt: $0.updatedAt
                )
            }
        )
    }

    static func exportProfile(from context: ModelContext, defaults: UserDefaults = .standard) -> ProfileDocument {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let profile = profiles.first

        var document = ProfileDocument(
            version: ProfileDocument.currentVersion,
            id: profile?.uuid,
            displayName: profile?.displayName ?? "",
            avatarBase64: profile?.avatarData?.base64EncodedString(),
            age: profile?.age,
            genderRaw: profile?.genderRaw ?? UserGender.unspecified.rawValue,
            appThemeRaw: defaults.string(forKey: "appTheme") ?? AppTheme.system.rawValue,
            accentPaletteRaw: defaults.string(forKey: AccentPalette.storageKey)
                ?? AccentPalette.orange.rawValue,
            status: ProfileStatus.load(defaults: defaults),
            createdAt: profile?.createdAt ?? .now
        )
        document.normalize()
        return document
    }
}
