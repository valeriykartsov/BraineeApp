//
//  TaskListDisplaySettingsView.swift
//  BraineeApp
//
//  Окно настройки: какие поля задачи показывать в списке.

import SwiftUI

struct TaskListDisplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: TaskListDisplaySettings

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
                    Toggle("Теги", isOn: $settings.showTags)
                } header: {
                    Text("Показывать в списке")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .tint(DesignSystem.Colors.accent)
                .listRowBackground(DesignSystem.Colors.surface)
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
                        settings.save()
                        dismiss()
                    }
                }
            }
            .onChange(of: settings) { _, newValue in
                newValue.save()
            }
        }
    }
}

#Preview {
    TaskListDisplaySettingsView(settings: .constant(.default))
}
