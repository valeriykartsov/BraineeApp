//
//  AppRootView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if isReady {
                MainTabView()
                    .persistOnBackground()
            } else if let loadError {
                ContentUnavailableView {
                    Label("Ошибка загрузки", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                }
            } else {
                ProgressView("Загрузка данных…")
            }
        }
        .task {
            do {
                try AppDataPersistence.bootstrap(into: modelContext)
                isReady = true
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
