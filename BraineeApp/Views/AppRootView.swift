//
//  AppRootView.swift
//  BraineeApp
//
//  Корневой экран: подготовка при запуске, splash-экран и переход к основному интерфейсу.

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var isReady = false
    @State private var showLaunch = true

    private var colorScheme: ColorScheme? {
        AppTheme.resolved(from: appThemeRaw).colorScheme
    }

    var body: some View {
        ZStack {
            if isReady {
                AnimatedMainTabView()
                    .saveOnBackground()
                    .opacity(showLaunch ? 0 : 1)
            }

            if showLaunch || !isReady {
                LaunchScreenView(playsLogoAnimation: true)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
        // Ссылка из события календаря (braineeapp://task/<uuid>, CAL-2) открывает задачу.
        .onOpenURL { url in
            if let uuid = CalendarEventRules.taskUUID(from: url) {
                NotificationDeepLinkRouter.shared.openTask(uuid: uuid)
            }
        }
        .task {
            AppDataPersistence.bootstrap(into: modelContext)
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

            // Даём доиграть анимации полос логотипа.
            try? await Task.sleep(for: .seconds(2.0))

            withAnimation(.easeOut(duration: 0.35)) {
                showLaunch = false
            }
        }
    }
}

/// Экран ошибки загрузки: хранилище данных не открылось (BraineeAppApp).
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
