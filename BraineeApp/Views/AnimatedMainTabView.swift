//
//  AnimatedMainTabView.swift
//  BraineeApp
//
//  Компактная нижняя панель в духе HeadHunter: низкая высота, плотная пара иконка+подпись.

import SwiftUI

struct AnimatedMainTabView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @State private var selectedTab: MainTab = .career

    private var colorScheme: ColorScheme? {
        AppTheme.resolved(from: appThemeRaw).colorScheme
    }

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tabContent(for: selectedTab)
                    .id(selectedTab)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)

            AppDivider()
            tabBar
        }
        .appScreenBackground()
        .tint(accentColor)
        .preferredColorScheme(colorScheme)
        .onAppear {
            AppNavigationChrome.apply()
        }
        .onChange(of: appThemeRaw) { _, _ in
            AppNavigationChrome.apply()
        }
        .onChange(of: accentPaletteRaw) { _, _ in
            AppNavigationChrome.apply()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: MainTab) -> some View {
        switch tab {
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let isActive = selectedTab == tab
                Button {
                    guard selectedTab != tab else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isActive ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                            .frame(height: 22)

                        Text(tab.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        // Подчёркивание активного раздела.
                        Capsule(style: .continuous)
                            .fill(isActive ? accentColor : Color.clear)
                            .frame(width: 22, height: 2)
                            .padding(.top, 1)
                    }
                    .foregroundStyle(isActive ? accentColor : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
        .background(DesignSystem.Colors.surface.ignoresSafeArea(edges: .bottom))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

#Preview {
    AnimatedMainTabView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self], inMemory: true)
}
