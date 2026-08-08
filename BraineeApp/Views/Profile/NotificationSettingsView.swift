//
//  NotificationSettingsView.swift
//  BraineeApp
//
//  Настройки уведомлений: мастер-свитчер и детальные опции.

import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings = NotificationSettings.load()
    @State private var systemStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Space.sectionGap) {
                GroupedSection(title: "Уведомления") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        Toggle(isOn: Binding(
                            get: { settings.isEnabled },
                            set: { newValue in
                                Task { await setMasterEnabled(newValue) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Разрешить уведомления")
                                    .font(DesignSystem.Typography.body(16))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(systemStatusFooter)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .tint(DesignSystem.Colors.accent)

                        if systemStatus == .denied {
                            Button("Открыть настройки устройства") {
                                Task { @MainActor in
                                    AppNotifications.openSystemSettings()
                                }
                            }
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                    .padding(DesignSystem.Space.x3)
                }

                if settings.isEnabled {
                    GroupedSection(title: "Задачи") {
                        toggleRow(
                            title: "Напоминания о задачах",
                            subtitle: "Ежедневно, если есть незакрытые задачи",
                            isOn: Binding(
                                get: { settings.tasksEnabled },
                                set: {
                                    settings.tasksEnabled = $0
                                    persistAndRefresh()
                                }
                            )
                        )
                    }

                    GroupedSection(title: "Привычки") {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                            Toggle(isOn: Binding(
                                get: { settings.habitsEnabled },
                                set: {
                                    settings.habitsEnabled = $0
                                    persistAndRefresh()
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Напоминания о привычках")
                                        .font(DesignSystem.Typography.body(16))
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text("Ежедневное напоминание")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .tint(DesignSystem.Colors.accent)

                            if settings.habitsEnabled {
                                DatePicker(
                                    "Время напоминания",
                                    selection: Binding(
                                        get: { settings.habitsReminderDate },
                                        set: {
                                            settings.habitsReminderDate = $0
                                            persistAndRefresh()
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .tint(DesignSystem.Colors.accent)
                            }
                        }
                        .padding(DesignSystem.Space.x3)
                    }

                    GroupedSection(title: "Дедлайн") {
                        VStack(spacing: 0) {
                            toggleRow(
                                title: "При приближении",
                                subtitle: "Общее правило или напоминание из карточки задачи",
                                isOn: Binding(
                                    get: { settings.deadlineApproachingEnabled },
                                    set: {
                                        settings.deadlineApproachingEnabled = $0
                                        persistAndRefresh()
                                    }
                                ),
                                showDividerBelow: true
                            )

                            toggleRow(
                                title: "Просроченный срок",
                                subtitle: "Напоминание, если дедлайн уже прошёл",
                                isOn: Binding(
                                    get: { settings.deadlineOverdueEnabled },
                                    set: {
                                        settings.deadlineOverdueEnabled = $0
                                        persistAndRefresh()
                                    }
                                ),
                                showDividerBelow: false
                            )
                        }
                    }
                }
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("Уведомления")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
        .task {
            await reloadStatus()
            settings = NotificationSettings.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reloadStatus() }
            }
        }
    }

    private var systemStatusFooter: String {
        switch systemStatus {
        case .denied:
            return "Разрешение отклонено в настройках устройства"
        case .authorized, .provisional, .ephemeral:
            return "Системное разрешение получено"
        case .notDetermined:
            return "Система ещё не запрашивала разрешение"
        @unknown default:
            return "Статус разрешения неизвестен"
        }
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        showDividerBelow: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.body(16))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.accent)
            .padding(DesignSystem.Space.x3)

            if showDividerBelow {
                InsetDivider(leading: DesignSystem.Space.x3)
            }
        }
    }

    @MainActor
    private func setMasterEnabled(_ enabled: Bool) async {
        await AppNotifications.setMasterEnabled(
            enabled,
            tasks: modelContext.fetchActiveTasks(),
            habits: modelContext.fetchHabits()
        )
        settings = NotificationSettings.load()
        await reloadStatus()
    }

    private func persistAndRefresh() {
        settings.save()
        let tasks = modelContext.fetchActiveTasks()
        let habits = modelContext.fetchHabits()
        Task {
            await AppNotifications.refresh(tasks: tasks, habits: habits)
        }
    }

    private func reloadStatus() async {
        systemStatus = await AppNotifications.authorizationStatus()
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .modelContainer(for: [TaskItem.self, Habit.self], inMemory: true)
}
