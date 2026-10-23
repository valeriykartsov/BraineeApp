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

    /// Данные живут в SwiftData-файле. Хранилище V1 при первом запуске переводится на V2 с бэкапом
    /// и сверкой (`SchemaUpgrade`, D-39). Если хранилище не открылось — экран ошибки вместо падения приложения.
    private let sharedModelContainer = Result {
        try SchemaUpgrade.standard.openStore()
    }

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
