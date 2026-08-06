//
//  AnimatedMainTabView.swift
//  BraineeApp
//

import SwiftUI

enum MainTab: Int, CaseIterable, Identifiable {
    case career
    case sport
    case mental
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .career: TaskCategory.career.title
        case .sport: TaskCategory.sport.title
        case .mental: TaskCategory.mental.title
        case .profile: "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .career: TaskCategory.career.systemImage
        case .sport: TaskCategory.sport.systemImage
        case .mental: TaskCategory.mental.systemImage
        case .profile: "person.circle.fill"
        }
    }

    var category: TaskCategory? {
        switch self {
        case .career: .career
        case .sport: .sport
        case .mental: .mental
        case .profile: nil
        }
    }
}

struct AnimatedMainTabView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var selectedTab: MainTab = .career
    @Namespace private var tabNamespace

    private var colorScheme: ColorScheme? {
        (AppTheme(rawValue: appThemeRaw) ?? .system).colorScheme
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .career:
                    TaskSectionView(category: .career)
                case .sport:
                    TaskSectionView(category: .sport)
                case .mental:
                    TaskSectionView(category: .mental)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .preferredColorScheme(colorScheme)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.caption2.weight(selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                                .matchedGeometryEffect(id: "tabSlider", in: tabNamespace)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

#Preview {
    AnimatedMainTabView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
