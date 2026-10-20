//
//  BraineeAppApp.swift
//  BraineeApp
//
//  Точка входа приложения: создаёт SwiftData-контейнер в памяти и открывает AppRootView.

import SwiftUI
import SwiftData

@main
struct BraineeAppApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

    /// SwiftData живёт только в памяти; постоянные данные — в JSON (см. AppDataPersistence).
    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.make(.inMemory)
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
