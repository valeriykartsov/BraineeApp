//
//  TaskListDisplaySettingsView.swift
//  BraineeApp
//
//  Окно настройки: какие поля задачи показывать в списке и показывать ли выполненные.
//  Один экран для вкладок «Задачи» и «Календарь»; у каждой свой ключ хранения (п. 43).

import SwiftUI

struct TaskListDisplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: TaskListDisplaySettings
    var storageKey = TaskListDisplaySettings.storageKey
    /// В режиме канбана выполненные не скрываются — переключатель не показываем.
    var showsCompletedToggle = true
    /// «Разбить по папкам» — только в режиме канбана вкладки «Задачи» (п. 44).
    var showsKanbanFoldersToggle = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignSystem.Space.x3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("Название")
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Text("Всегда")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .listRowBackground(DesignSystem.Colors.surface)
                } header: {
                    Text("Обязательно")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                } footer: {
                    Text("Название задачи всегда отображается в списке.")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Section {
                    Toggle("Детали", isOn: $settings.showDetails)
                    Toggle("Дедлайн", isOn: $settings.showDeadline)
                    Toggle("Приоритет", isOn: $settings.showPriority)
                    Toggle("Статус", isOn: $settings.showStatus)
                    Toggle("Теги", isOn: $settings.showTags)
                    Toggle("Подзадачи", isOn: $settings.showSubtasks)
                } header: {
                    Text("Показывать в списке")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .tint(DesignSystem.Colors.accent)
                .listRowBackground(DesignSystem.Colors.surface)

                if showsKanbanFoldersToggle {
                    Section {
                        Toggle("Разбить по папкам", isOn: $settings.kanbanByFolder)
                    } header: {
                        Text("Канбан")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .textCase(nil)
                    } footer: {
                        Text("Отдельная доска для каждой папки с задачами, «Входящие» — последней. Карточку можно перенести в другую колонку своей доски; папку задачи меняют в списке.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .tint(DesignSystem.Colors.accent)
                    .listRowBackground(DesignSystem.Colors.surface)
                }

                if showsCompletedToggle {
                    Section {
                        Toggle("Показывать выполненные", isOn: $settings.showCompleted)
                    } header: {
                        Text("Выполненные")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .textCase(nil)
                    } footer: {
                        Text("Скрывает выполненные только в этом списке. Дашборд, наклейка на иконке и виджеты считают все задачи.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .tint(DesignSystem.Colors.accent)
                    .listRowBackground(DesignSystem.Colors.surface)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Отображение")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        settings.save(key: storageKey)
                        dismiss()
                    }
                }
            }
            .onChange(of: settings) { _, newValue in
                newValue.save(key: storageKey)
            }
        }
    }
}

#Preview {
    TaskListDisplaySettingsView(settings: .constant(.default))
}
