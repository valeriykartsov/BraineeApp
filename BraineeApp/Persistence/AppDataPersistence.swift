//
//  AppDataPersistence.swift
//  BraineeApp
//
//  Связь SwiftData и JSON: загрузка при старте (перенос JSON при первом запуске), экспорт после изменений.

import Foundation
import SwiftData
import SwiftUI

enum AppDataPersistence {
    /// Загрузка при запуске (SD-3). Данные живут в постоянном хранилище SwiftData и при старте
    /// не очищаются и не перезаписываются. При первом запуске (нет маркера) JSON переносится
    /// мигратором: бэкап → копирование → проверка → маркер. Сбой переноса — ошибка, маркер не ставится,
    /// следующий запуск повторит перенос.
    @MainActor
    static func bootstrap(
        into context: ModelContext,
        location: AppDataStoreLocation = .standard,
        migrator: JSONToSwiftDataMigrator? = nil,
        defaults: UserDefaults = .standard
    ) throws {
        let migrator = migrator ?? JSONToSwiftDataMigrator()
        // Тема и акцент по-прежнему берутся из profile.json и UserDefaults.
        // Битый файл переименовывается и даёт ошибку один раз (BASE-3), как раньше.
        var profileDocument = try AppDataStore.loadProfile(location: location)
        if applyAccentDefaults(to: &profileDocument, defaults: defaults) {
            try? AppDataStore.saveProfile(profileDocument, location: location)
        }
        if defaults.object(forKey: "appTheme") == nil,
           profileDocument.appThemeRaw != AppTheme.system.rawValue {
            defaults.set(profileDocument.appThemeRaw, forKey: "appTheme")
        }

        if !migrator.isCompleted {
            // Битый mytasks.json без Keychain-копии переименовывается и даёт ошибку (BASE-3);
            // при следующем запуске перенос идёт без него, а не падает каждый раз.
            _ = try AppDataStore.loadTasks(location: location)
            do {
                try migrator.run(into: context.container)
            } catch {
                throw BootstrapError.migrationFailed(error.localizedDescription)
            }
        }

        WidgetSnapshotBuilder.publish(
            tasks: context.fetchActiveTasks(),
            habits: context.fetchHabits()
        )
    }

    enum BootstrapError: LocalizedError {
        case migrationFailed(String)

        var errorDescription: String? {
            switch self {
            case .migrationFailed(let reason):
                "Не удалось перенести данные в новое хранилище. \(reason) "
                    + "Исходные файлы не изменены; перенос повторится при следующем запуске."
            }
        }
    }

    /// Правила акцента при старте.
    /// - Первая установка / переустановка → оранжевый + маркер запуска.
    /// - Повторный запуск без ключа в UserDefaults → значение из profile.json.
    /// - Возвращает `true`, если profile нужно сохранить на диск.
    @discardableResult
    static func applyAccentDefaults(
        to profile: inout ProfileDocument,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let isFreshInstall = !defaults.bool(forKey: AccentPalette.hasLaunchedStorageKey)
        if isFreshInstall {
            profile.accentPaletteRaw = AccentPalette.orange.rawValue
            defaults.set(AccentPalette.orange.rawValue, forKey: AccentPalette.storageKey)
            defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
            return true
        }

        if defaults.object(forKey: AccentPalette.storageKey) == nil {
            defaults.set(profile.accentPaletteRaw, forKey: AccentPalette.storageKey)
        }
        return false
    }

    /// Сохраняет текущее состояние SwiftData обратно в JSON и Keychain.
    static func export(from context: ModelContext) {
        try? context.save()

        do {
            try AppDataStore.saveTasks(exportTasks(from: context))
            try AppDataStore.saveProfile(exportProfile(from: context))
        } catch {
            print("AppDataPersistence export failed: \(error)")
        }
    }

    // Используется мигратором (SD-2); round-trip JSON ↔ SwiftData — в AppDataPersistenceRoundTripTests.
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
                group: record.groupID.flatMap { groupByID[$0] },
                tags: tags
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
                    deletedAt: $0.isSoftDeleted ? ($0.deletedAt ?? .now) : nil,
                    updatedAt: $0.updatedAt,
                    completedAt: $0.completedAt
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

    static func exportProfile(from context: ModelContext) -> ProfileDocument {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let profile = profiles.first

        var document = ProfileDocument(
            version: ProfileDocument.currentVersion,
            id: profile?.uuid,
            displayName: profile?.displayName ?? "",
            avatarBase64: profile?.avatarData?.base64EncodedString(),
            age: profile?.age,
            genderRaw: profile?.genderRaw ?? UserGender.unspecified.rawValue,
            appThemeRaw: UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue,
            accentPaletteRaw: UserDefaults.standard.string(forKey: AccentPalette.storageKey)
                ?? AccentPalette.orange.rawValue,
            createdAt: profile?.createdAt ?? .now
        )
        document.normalize()
        return document
    }
}

extension ModelContext {
    /// Удобный вызов после любого изменения задач, профиля или тегов.
    func persistToJSON() {
        AppDataPersistence.export(from: self)
        let tasks = fetchActiveTasks()
        let habits = fetchHabits()
        WidgetSnapshotBuilder.publish(tasks: tasks, habits: habits)
        Task {
            await AppNotifications.refresh(tasks: tasks, habits: habits)
        }
    }
}

/// Автосохранение JSON, когда приложение уходит в фон.
struct JSONPersistenceModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                // Только background: inactive (шторка/переключатель приложений) иначе даёт лишний тяжёлый export.
                if phase == .background {
                    modelContext.persistToJSON()
                }
            }
    }
}

extension View {
    func persistOnBackground() -> some View {
        modifier(JSONPersistenceModifier())
    }
}
