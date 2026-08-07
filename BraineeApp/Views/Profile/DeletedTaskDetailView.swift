//
//  DeletedTaskDetailView.swift
//  BraineeApp
//
//  Просмотр удалённой задачи в стиле дизайн-системы.

import SwiftUI

struct DeletedTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem
    var onRestore: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("Название", value: task.title)
                LabeledContent("Раздел", value: task.category.title)
                if let group = task.group {
                    LabeledContent("Группа", value: group.name)
                }
            } header: {
                Text("Задача")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textCase(nil)
            }
            .listRowBackground(DesignSystem.Colors.surface)
            .foregroundStyle(DesignSystem.Colors.textPrimary)

            if !task.taskDetails.isEmpty {
                Section {
                    Text(task.taskDetails)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } header: {
                    Text("Описание")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)
            }

            Section {
                LabeledContent("Приоритет", value: task.priority.title)
                LabeledContent("Статус", value: task.isCompleted ? "Выполнена" : "Активна")
                if let deadline = task.deadline {
                    LabeledContent("Дедлайн", value: deadline.formatted(date: .abbreviated, time: .omitted))
                }
                if let deletedAt = task.deletedAt {
                    LabeledContent("Удалена", value: deletedAt.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Детали")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textCase(nil)
            }
            .listRowBackground(DesignSystem.Colors.surface)
            .foregroundStyle(DesignSystem.Colors.textPrimary)

            if !task.tags.isEmpty {
                Section {
                    TagFlowLayout(spacing: DesignSystem.Space.x2) {
                        ForEach(task.tags, id: \.uuid) { tag in
                            TagChipView(name: tag.name)
                        }
                    }
                } header: {
                    Text("Теги")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
        .tint(DesignSystem.Colors.accent)
        .navigationTitle("Просмотр")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Восстановить") {
                    onRestore()
                    dismiss()
                }
                .font(DesignSystem.Typography.headline(15))
                .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeletedTaskDetailView(
            task: TaskItem(title: "Пример", category: .career, isSoftDeleted: true, deletedAt: .now),
            onRestore: {}
        )
    }
}
