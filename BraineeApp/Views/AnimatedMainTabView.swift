//
//  AnimatedMainTabView.swift
//  BraineeApp
//
//  Главный экран с геометричной нижней панелью вкладок.

import SwiftUI

struct AnimatedMainTabView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var selectedTab: MainTab = .career
    @Namespace private var tabNamespace

    private var colorScheme: ColorScheme? {
        AppTheme.resolved(from: appThemeRaw).colorScheme
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

            PankinDivider()
            tabBar
        }
        .pankinScreenBackground()
        .tint(DesignSystem.Colors.accent)
        .preferredColorScheme(colorScheme)
        .onAppear {
            PankinNavigationChrome.apply()
        }
        .onChange(of: appThemeRaw) { _, _ in
            PankinNavigationChrome.apply()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(DesignSystem.Typography.tabLabel())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Space.x1)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                                .fill(DesignSystem.Colors.accent.opacity(0.12))
                                .matchedGeometryEffect(id: "tabSlider", in: tabNamespace)
                                .padding(.horizontal, DesignSystem.Space.x1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Space.x1)
        .padding(.top, DesignSystem.Space.x1)
        .padding(.bottom, DesignSystem.Space.x1)
        .background(DesignSystem.Colors.surface)
    }
}

#Preview {
    AnimatedMainTabView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
