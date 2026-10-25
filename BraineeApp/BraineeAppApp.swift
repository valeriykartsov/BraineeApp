//
//  BraineeAppApp.swift
//  BraineeApp
//
//  Точка входа приложения: открывает постоянное хранилище SwiftData (SD-3) и показывает AppRootView.

import SwiftUI
import SwiftData

@main
struct BraineeAppApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

    /// Данные живут в SwiftData-файле (`SharedModelContainer`, общий с кнопками уведомлений, D-46).
    /// Если хранилище не открылось — экран ошибки вместо падения приложения.
    private let sharedModelContainer = SharedModelContainer.result

    var body: some Scene {
        WindowGroup {
            switch sharedModelContainer {
            case .success(let container):
                AppRootView()
                    .modelContainer(container)
            case .failure(let error):
                LoadErrorView(message: "Не удалось открыть хранилище данных: \(error.localizedDescription)")
            }
        }
    }
}
