//
//  BraineeAppApp.swift
//  BraineeApp
//
//  Точка входа приложения: создаёт SwiftData-контейнер в памяти и открывает AppRootView.

import SwiftUI
import SwiftData

@main
struct BraineeAppApp: App {
    /// SwiftData живёт только в памяти; постоянные данные — в JSON (см. AppDataPersistence).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            TaskGroup.self,
            TaskTag.self,
            UserProfile.self,
            Habit.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
