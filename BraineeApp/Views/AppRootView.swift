//
//  AppRootView.swift
//  BraineeApp
//
//  Корневой экран: загрузка JSON, splash-экран и переход к основному интерфейсу.

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var isReady = false
    @State private var showLaunch = true
    @State private var loadError: String?

    private var colorScheme: ColorScheme? {
        AppTheme.resolved(from: appThemeRaw).colorScheme
    }

    var body: some View {
        ZStack {
            if isReady {
                AnimatedMainTabView()
                    .persistOnBackground()
                    .opacity(showLaunch ? 0 : 1)
            } else if let loadError {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                    Text("Ошибка загрузки")
                        .font(DesignSystem.Typography.title(22))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(loadError)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    PankinDivider()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DesignSystem.Space.x4)
                .pankinScreenBackground()
            }

            if showLaunch || !isReady {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
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
