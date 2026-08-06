//
//  AppRootView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false
    @State private var showLaunch = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            if isReady {
                AnimatedMainTabView()
                    .persistOnBackground()
                    .opacity(showLaunch ? 0 : 1)
            } else if let loadError {
                ContentUnavailableView {
                    Label("Ошибка загрузки", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                }
            }

            if showLaunch || !isReady {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .task {
            do {
                try AppDataPersistence.bootstrap(into: modelContext)
                isReady = true
            } catch {
                loadError = error.localizedDescription
            }

            try? await Task.sleep(for: .seconds(1.2))

            if isReady {
                withAnimation(.easeOut(duration: 0.35)) {
                    showLaunch = false
                }
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
