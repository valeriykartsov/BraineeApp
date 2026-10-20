//
//  AppRootView.swift
//  BraineeApp
//
//  Корневой экран: загрузка данных (перенос JSON при первом запуске), splash-экран и переход к основному интерфейсу.

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
                LoadErrorView(message: loadError)
            }

            // При ошибке загрузки заставка тоже уходит, иначе она навсегда закрывает текст ошибки.
            if showLaunch || (!isReady && loadError == nil) {
                LaunchScreenView(playsLogoAnimation: true)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
        .task {
            do {
                try AppDataPersistence.bootstrap(into: modelContext)
                isReady = true
                // Подтянуть иконку Springboard под сохранённый акцент (без алерта).
                AppIconSwitcher.syncWithCurrentAccent()
#if canImport(UIKit)
                OrientationLockSettings.apply(
                    lockPortrait: OrientationLockSettings.isPortraitLocked
                )
#endif
                AppNotifications.requestPermissionOnFirstLaunchIfNeeded()
                await AppNotifications.refresh(from: modelContext)
            } catch {
                loadError = error.localizedDescription
            }

            // Даём доиграть анимации полос логотипа.
            try? await Task.sleep(for: .seconds(2.0))

            if isReady || loadError != nil {
                withAnimation(.easeOut(duration: 0.35)) {
                    showLaunch = false
                }
            }
        }
    }
}

/// Экран ошибки загрузки: битый файл, сбой переноса данных или хранилище не открылось.
struct LoadErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
            Text("Ошибка загрузки")
                .font(DesignSystem.Typography.title(22))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(message)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            AppDivider()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Space.x4)
        .appScreenBackground()
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
