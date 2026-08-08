//
//  TabBarSettingsView.swift
//  BraineeApp
//
//  Выбор вкладок нижней панели. Задачи и Профиль всегда; остальное — по желанию.

import SwiftUI

struct TabBarSettingsView: View {
    @AppStorage(TabBarSettings.showCalendarKey) private var showCalendar = true
    @AppStorage(TabBarSettings.showMatrixKey) private var showMatrix = false
    @AppStorage(TabBarSettings.showHabitsKey) private var showHabits = false

    var body: some View {
        Form {
            Section {
                alwaysOnRow(title: "Задачи", systemImage: "checklist")

                optionalToggle(
                    title: "Календарь",
                    systemImage: DesignSystem.Icon.calendar,
                    isOn: $showCalendar
                ) { newValue in
                    persist(showCalendar: newValue, showMatrix: showMatrix, showHabits: showHabits)
                }

                optionalToggle(
                    title: "Матрица",
                    systemImage: "square.grid.2x2",
                    isOn: $showMatrix
                ) { newValue in
                    persist(showCalendar: showCalendar, showMatrix: newValue, showHabits: showHabits)
                }

                optionalToggle(
                    title: "Привычки",
                    systemImage: "flame",
                    isOn: $showHabits
                ) { newValue in
                    persist(showCalendar: showCalendar, showMatrix: showMatrix, showHabits: newValue)
                }

                alwaysOnRow(title: "Профиль", systemImage: DesignSystem.Icon.person)
            } header: {
                Text("Вкладки")
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textCase(nil)
            } footer: {
                Text("Порядок в меню: Задачи → Календарь → Матрица → Привычки → Профиль. Задачи и Профиль всегда видны.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
        .navigationTitle("Панель вкладок")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
    }

    private func alwaysOnRow(title: String, systemImage: String) -> some View {
        HStack(spacing: DesignSystem.Space.x3) {
            Image(systemName: systemImage)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.Space.x5)
            Text(title)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
            Text("Всегда")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .listRowBackground(DesignSystem.Colors.surface)
    }

    private func optionalToggle(
        title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        .tint(DesignSystem.Colors.accent)
        .listRowBackground(DesignSystem.Colors.surface)
        .onChange(of: isOn.wrappedValue) { _, newValue in
            onChange(newValue)
        }
    }

    private func persist(showCalendar: Bool, showMatrix: Bool, showHabits: Bool) {
        TabBarSettings(
            showCalendar: showCalendar,
            showMatrix: showMatrix,
            showHabits: showHabits
        ).save()
    }
}

#Preview {
    NavigationStack {
        TabBarSettingsView()
    }
}
