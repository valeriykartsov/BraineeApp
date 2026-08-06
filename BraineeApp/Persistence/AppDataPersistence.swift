//
//  AppDataPersistence.swift
//  BraineeApp
//

import Foundation
import SwiftData
import SwiftUI

enum AppDataPersistence {
    static func bootstrap(into context: ModelContext) throws {
        try AppDataStore.prepareStorage()
        clearAllData(in: context)

        let tasksDocument = try AppDataStore.loadTasks()
        let profileDocument = try AppDataStore.loadProfile()

        importTasks(tasksDocument, into: context)
        importProfile(profileDocument, into: context)

        if UserDefaults.standard.object(forKey: "appTheme") == nil,
           profileDocument.appThemeRaw != AppTheme.system.rawValue {
            UserDefaults.standard.set(profileDocument.appThemeRaw, forKey: "appTheme")
        }

        try context.save()
    }

    static func export(from context: ModelContext) {
        do {
            try context.save()
            try AppDataStore.saveTasks(exportTasks(from: context))
            try AppDataStore.saveProfile(exportProfile(from: context))
        } catch {
            print("AppDataPersistence export failed: \(error)")
        }
    }

    private static func clearAllData(in context: ModelContext) {
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: TaskGroup.self)
        try? context.delete(model: TaskTag.self)
        try? context.delete(model: UserProfile.self)
    }

    private static func importTasks(_ document: MyTasksDocument, into context: ModelContext) {
        var tagByID: [UUID: TaskTag] = [:]
        for record in document.tags {
            let tag = TaskTag(name: record.name, uuid: record.id, createdAt: record.createdAt)
            context.insert(tag)
            tagByID[record.id] = tag
        }

        var groupByID: [UUID: TaskGroup] = [:]
        for record in document.groups {
            let group = TaskGroup(
                name: record.name,
                category: TaskCategory(rawValue: record.categoryRaw) ?? .career,
                sortOrder: record.sortOrder,
                uuid: record.id,
                createdAt: record.createdAt
            )
            context.insert(group)
            groupByID[record.id] = group
        }

        for record in document.tasks {
            let tags = record.tagIDs.compactMap { tagByID[$0] }
            let task = TaskItem(
                title: record.title,
                isCompleted: record.isCompleted,
                deadline: record.deadline,
                priority: TaskPriority(rawValue: record.priorityRaw) ?? .medium,
                category: TaskCategory(rawValue: record.categoryRaw) ?? .career,
                createdAt: record.createdAt,
                taskDetails: record.taskDetails,
                sortOrder: record.sortOrder,
                uuid: record.id,
                group: record.groupID.flatMap { groupByID[$0] },
                tags: tags
            )
            context.insert(task)
        }
    }

    private static func importProfile(_ document: ProfileDocument, into context: ModelContext) {
        let avatarData = document.avatarBase64.flatMap { Data(base64Encoded: $0) }
        let profile = UserProfile(
            displayName: document.displayName,
            avatarData: avatarData,
            createdAt: document.createdAt
        )
        context.insert(profile)
    }

    private static func exportTasks(from context: ModelContext) -> MyTasksDocument {
        let tags = (try? context.fetch(FetchDescriptor<TaskTag>())) ?? []
        let groups = (try? context.fetch(FetchDescriptor<TaskGroup>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []

        return MyTasksDocument(
            version: 1,
            tags: tags.map { TagRecord(id: $0.uuid, name: $0.name, createdAt: $0.createdAt) },
            groups: groups.map {
                GroupRecord(
                    id: $0.uuid,
                    name: $0.name,
                    categoryRaw: $0.categoryRaw,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt
                )
            },
            tasks: tasks.map {
                TaskRecord(
                    id: $0.uuid,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    deadline: $0.deadline,
                    priorityRaw: $0.priorityRaw,
                    categoryRaw: $0.categoryRaw,
                    createdAt: $0.createdAt,
                    taskDetails: $0.taskDetails,
                    sortOrder: $0.sortOrder,
                    groupID: $0.group?.uuid,
                    tagIDs: $0.tags.map(\.uuid)
                )
            }
        )
    }

    private static func exportProfile(from context: ModelContext) -> ProfileDocument {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let profile = profiles.first

        return ProfileDocument(
            version: 1,
            displayName: profile?.displayName ?? "",
            avatarBase64: profile?.avatarData?.base64EncodedString(),
            appThemeRaw: UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue,
            createdAt: profile?.createdAt ?? .now
        )
    }
}

extension ModelContext {
    func persistToJSON() {
        AppDataPersistence.export(from: self)
    }
}

struct JSONPersistenceModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase == .background || phase == .inactive {
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
