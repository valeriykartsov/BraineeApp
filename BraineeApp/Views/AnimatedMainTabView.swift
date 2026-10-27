//
//  AnimatedMainTabView.swift
//  BraineeApp
//
//  Нижняя панель — плавающая капсула (п. 60): выделение «перетекает» между разделами;
//  над картинкой фона с включённым «Стеклом» капсула стеклянная.
//  Контент табов не уничтожается при переключении — без лагов от пересоздания @Query.

import SwiftUI
import SwiftData

struct AnimatedMainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @AppStorage(TabBarSettings.showCalendarKey) private var showCalendar = true
    @AppStorage(TabBarSettings.showLLMKey) private var showLLM = false
    @AppStorage(TabBarSettings.showHabitsKey) private var showHabits = false
    @AppStorage(NotificationSettings.iconBadgeModeKey) private var iconBadgeModeRaw = AppIconBadgeMode.overdue.rawValue

    @Query(filter: #Predicate<TaskItem> { !$0.isSoftDeleted })
    private var tasks: [TaskItem]

    @ObservedObject private var deepLinkRouter = NotificationDeepLinkRouter.shared
    @State private var selectedTab: MainTab = .tasks
    /// Повторное нажатие на вкладку «Профиль» — возврат в её корень (п. 41).
    @State private var profileRootRequest = 0
    /// Клавиатура и низ корня: панель остаётся внизу, отступ получает только содержимое (п. 57).
    @StateObject private var keyboard = KeyboardObserver()
    @State private var contentBottom: CGFloat = 0

    // Стекло (п. 60): считается здесь один раз и передаётся всем экранам через окружение.
    @AppStorage(AppBackgroundSettings.modeKey) private var backgroundModeRaw = AppBackgroundMode.none.rawValue
    @AppStorage(AppGlassSettings.enabledKey) private var glassEnabled = false
    @AppStorage(AppGlassSettings.levelKey) private var glassLevel = AppGlassSettings.defaultLevel
    @ObservedObject private var backgroundStore = AppBackgroundStore.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Высота капсулы и зазор над ней — столько места резервирует содержимое вкладок.
    private static let tabBarHeight: CGFloat = 60
    private static let tabBarGap: CGFloat = 8
    @Namespace private var tabUnderlineNamespace

    init() {
        // До первого чтения @AppStorage: прежний флаг «Матрицы» становится флагом «LLM» (NAV-1).
        TabBarSettings.migrateLegacyMatrixFlag()
    }

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
            showLLM: showLLM,
            showHabits: showHabits
        )
    }

    private var tabVisibilityToken: String {
        "\(showCalendar)-\(showLLM)-\(showHabits)"
    }

    private var iconBadgeMode: AppIconBadgeMode {
        AppIconBadgeMode.resolved(from: iconBadgeModeRaw)
    }

    private var tasksTabBadgeText: String? {
        let count = AppBadgeCounter.count(tasks: Array(tasks), mode: iconBadgeMode)
        return AppBadgeCounter.displayText(for: count)
    }

    private var glass: GlassAppearance {
        GlassAppearance.resolve(
            mode: AppBackgroundMode.resolved(from: backgroundModeRaw),
            hasImage: backgroundStore.hasImage,
            enabled: glassEnabled,
            level: glassLevel,
            reduceTransparency: reduceTransparency
        )
    }

    private var contentBottomInset: CGFloat {
        KeyboardLayout.contentBottomInset(
            tabBarReserve: Self.tabBarHeight + Self.tabBarGap,
            contentBottom: contentBottom,
            keyboardTop: keyboard.keyboardTop
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                TaskSectionView(isActive: selectedTab == .tasks)
                    .opacity(selectedTab == .tasks ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tasks)

                CalendarWeekView(isActive: selectedTab == .calendar)
                    .opacity(selectedTab == .calendar ? 1 : 0)
                    .allowsHitTesting(selectedTab == .calendar)

                LLMTabView(isActive: selectedTab == .llm)
                    .opacity(selectedTab == .llm ? 1 : 0)
                    .allowsHitTesting(selectedTab == .llm)

                HabitsView()
                    .opacity(selectedTab == .habits ? 1 : 0)
                    .allowsHitTesting(selectedTab == .habits)

                ProfileView(isActive: selectedTab == .profile, rootRequest: profileRootRequest)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Место под капсулу резервирует каждый экран внутри себя (`appScreenBackground` → `TabBarBottomInset`):
            // прокрутка идёт под капсулой, а конец списка встаёт над ней (п. 61).
            .environment(\.tabBarReserve, contentBottomInset)

            tabBar
                .padding(.horizontal, DesignSystem.Space.x4)
        }
        // Панель вкладок не поднимается над клавиатурой: даже от «призрачной» клавиатуры
        // (закрытое поле, свёрнутое приложение) не остаётся пустой полосы под панелью (п. 57).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).maxY
        } action: { bottom in
            contentBottom = bottom
        }
        .environment(\.appGlass, glass)
        .appScreenBackground()
        .tint(accentColor)
        .preferredColorScheme(colorScheme)
        .onAppear {
            AppNavigationChrome.apply(accentRaw: accentPaletteRaw)
            ensureSelectedTabVisible()
            // Холодный запуск с виджета: ссылка пришла раньше, чем появился этот экран.
            openPendingCalendar()
            if deepLinkRouter.pendingPomodoro {
                selectedTab = .profile
            }
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
        .onChange(of: deepLinkRouter.pendingCalendarToday) { _, _ in
            openPendingCalendar()
        }
        // Помодоро — в «Профиле»; экран открывает ProfileView и сбрасывает флаг (D-47).
        .onChange(of: deepLinkRouter.pendingPomodoro) { _, pending in
            guard pending else { return }
            withAnimation(flowAnimation) {
                selectedTab = .profile
            }
        }
        .onChange(of: deepLinkRouter.pendingTaskUUID) { _, uuid in
            guard uuid != nil else { return }
            withAnimation(flowAnimation) {
                selectedTab = .tasks
            }
        }
        // Поле скрытой вкладки не должно держать клавиатуру над другой вкладкой (п. 57).
        .onChange(of: selectedTab) { _, _ in
            KeyboardLayout.endEditing()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                KeyboardLayout.endEditing()
            }
            if phase == .active {
                PomodoroController.shared.sync()
                Task { await AppNotifications.refresh(from: modelContext) }
                // Календарь «BraineeApp» могли удалить или поправить в приложении Календарь (CAL-2).
                CalendarExport.syncIfEnabled(context: modelContext)
            }
        }
        .onChange(of: iconBadgeModeRaw) { _, _ in
            Task { await AppBadgeSync.sync(tasks: Array(tasks)) }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                let isActive = selectedTab == tab
                Button {
                    guard selectedTab != tab else {
                        if tab == .profile { profileRootRequest += 1 }
                        return
                    }
                    withAnimation(flowAnimation) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: isActive ? tab.selectedSystemImage : tab.systemImage)
                                .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                                .frame(width: 28, height: 22)

                            if tab == .tasks, let badge = tasksTabBadgeText {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(DesignSystem.Colors.danger)
                                    )
                                    .offset(x: 10, y: -5)
                                    .accessibilityLabel("\(badge) по выбранному режиму наклейки")
                            }
                        }
                        .frame(height: 22)

                        Text(tab.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isActive ? accentColor : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.tabBarHeight - 10)
                    .background {
                        if isActive {
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.10))
                                .matchedGeometryEffect(id: "tabSelection", in: tabUnderlineNamespace)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .animation(flowAnimation, value: tabVisibilityToken)
        .padding(.horizontal, 5)
        .frame(height: Self.tabBarHeight)
        // Без стекла — сплошная капсула цвета карточки, как прежняя панель.
        .appGlassControl(in: Capsule(style: .continuous), solid: DesignSystem.Colors.surface)
        .shadow(color: .black.opacity(glass.controls ? 0.25 : 0.12), radius: 12, y: 4)
    }

    /// Виджет экрана блокировки открывает «Календарь»; если вкладка скрыта — «Задачи».
    private func openPendingCalendar() {
        guard deepLinkRouter.pendingCalendarToday else { return }
        let tab: MainTab = visibleTabs.contains(.calendar) ? .calendar : .tasks
        withAnimation(flowAnimation) {
            selectedTab = tab
        }
        // Сбрасывает флаг CalendarWeekView, когда покажет сегодняшний день.
        if tab != .calendar {
            deepLinkRouter.clearPendingCalendar()
        }
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
