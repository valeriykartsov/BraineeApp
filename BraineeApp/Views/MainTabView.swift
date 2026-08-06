//
//  MainTabView.swift
//  BraineeApp
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    private var colorScheme: ColorScheme? {
        (AppTheme(rawValue: appThemeRaw) ?? .system).colorScheme
    }

    var body: some View {
        TabView {
            TaskSectionView(category: .career)
                .tabItem {
                    Label(TaskCategory.career.title, systemImage: TaskCategory.career.systemImage)
                }

            TaskSectionView(category: .sport)
                .tabItem {
                    Label(TaskCategory.sport.title, systemImage: TaskCategory.sport.systemImage)
                }

            TaskSectionView(category: .mental)
                .tabItem {
                    Label(TaskCategory.mental.title, systemImage: TaskCategory.mental.systemImage)
                }

            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.circle.fill")
                }
        }
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
