//
//  DeletedTaskDetailView.swift
//  BraineeApp
//
//  Просмотр удалённой задачи только для чтения с кнопкой «Восстановить».

import SwiftUI

struct DeletedTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem
    var onRestore: () -> Void

    var body: some View {
        List {
            Section("Задача") {
                LabeledContent("Название", value: task.title)
                LabeledContent("Раздел", value: task.category.title)
                if let group = task.group {
                    LabeledContent("Группа", value: group.name)
                }
            }

            if !task.taskDetails.isEmpty {
                Section("Описание") {
                    Text(task.taskDetails)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Детали") {
                LabeledContent("Приоритет", value: task.priority.title)
                LabeledContent("Статус", value: task.isCompleted ? "Выполнена" : "Активна")
                if let deadline = task.deadline {
                    LabeledContent("Дедлайн", value: deadline.formatted(date: .abbreviated, time: .omitted))
                }
                if let deletedAt = task.deletedAt {
                    LabeledContent("Удалена", value: deletedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if !task.tags.isEmpty {
                Section("Теги") {
                    TagFlowLayout(spacing: 8) {
                        ForEach(task.tags, id: \.uuid) { tag in
                            TagChipView(name: tag.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Просмотр")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Восстановить") {
                    onRestore()
                    // Возврат к списку «Удалённые», чтобы карточка сразу исчезла.
                    dismiss()
                }
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
