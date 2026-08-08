//
//  AnimatedMainTabView.swift
//  BraineeApp
//
//  Компактная нижняя панель: подчёркивание «перетекает» между разделами.
//  Контент табов не уничтожается при переключении — без лагов от пересоздания @Query.

import SwiftUI

struct AnimatedMainTabView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @AppStorage(TabBarSettings.showCalendarKey) private var showCalendar = true
    @AppStorage(TabBarSettings.showMatrixKey) private var showMatrix = false
    @AppStorage(TabBarSettings.showHabitsKey) private var showHabits = false
    @State private var selectedTab: MainTab = .tasks
    @Namespace private var tabUnderlineNamespace

    private var colorScheme: ColorScheme? {
        AppTheme.resolved(from: appThemeRaw).colorScheme
    }

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    private var flowAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }

    private var visibleTabs: [MainTab] {
        MainTab.visibleTabs(
            showCalendar: showCalendar,
            showMatrix: showMatrix,
            showHabits: showHabits
        )
    }

    private var tabVisibilityToken: String {
        "\(showCalendar)-\(showMatrix)-\(showHabits)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TaskSectionView(isActive: selectedTab == .tasks)
                    .opacity(selectedTab == .tasks ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tasks)

                CalendarWeekView(isActive: selectedTab == .calendar)
                    .opacity(selectedTab == .calendar ? 1 : 0)
                    .allowsHitTesting(selectedTab == .calendar)

                EisenhowerMatrixView()
                    .opacity(selectedTab == .matrix ? 1 : 0)
                    .allowsHitTesting(selectedTab == .matrix)

                HabitsView()
                    .opacity(selectedTab == .habits ? 1 : 0)
                    .allowsHitTesting(selectedTab == .habits)

                ProfileView(isActive: selectedTab == .profile)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            tabBar
        }
        .appScreenBackground()
        .tint(accentColor)
        .preferredColorScheme(colorScheme)
        .onAppear {
            AppNavigationChrome.apply(accentRaw: accentPaletteRaw)
            ensureSelectedTabVisible()
        }
        .onChange(of: appThemeRaw) { _, _ in
            AppNavigationChrome.apply(accentRaw: accentPaletteRaw)
        }
        .onChange(of: accentPaletteRaw) { _, newValue in
            AppNavigationChrome.apply(accentRaw: newValue)
        }
        .onChange(of: tabVisibilityToken) { _, _ in
            withAnimation(flowAnimation) {
                ensureSelectedTabVisible()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                let isActive = selectedTab == tab
                Button {
                    guard selectedTab != tab else { return }
                    withAnimation(flowAnimation) {
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

                        ZStack {
                            Color.clear.frame(width: 22, height: 2)
                            if isActive {
                                Capsule(style: .continuous)
                                    .fill(accentColor)
                                    .frame(width: 22, height: 2)
                                    .matchedGeometryEffect(id: "tabUnderline", in: tabUnderlineNamespace)
                            }
                        }
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
        .animation(flowAnimation, value: tabVisibilityToken)
        .padding(.horizontal, 4)
        .background(DesignSystem.Colors.surface.ignoresSafeArea(edges: .bottom))
    }

    private func ensureSelectedTabVisible() {
        if !visibleTabs.contains(selectedTab) {
            selectedTab = .tasks
        }
    }
}

#Preview {
    AnimatedMainTabView()
        .modelContainer(
            for: [TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self, Habit.self],
            inMemory: true
        )
}
