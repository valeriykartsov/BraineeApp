//
//  AddEditTaskView.swift
//  BraineeApp
//

import SwiftUI

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss

    let category: TaskCategory
    var task: TaskItem?
    var onSave: (String, Date?, TaskPriority) -> Void

    @State private var title = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var priority: TaskPriority = .medium

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    TextField("Название", text: $title)
                }

                Section("Дедлайн") {
                    Toggle("Указать дату", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "Дата исполнения",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                    }
                }

                Section("Приоритет") {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases) { level in
                            HStack {
                                Circle()
                                    .fill(PriorityStyle.color(for: level))
                                    .frame(width: 10, height: 10)
                                Text(level.title)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новая задача")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let task else { return }
                title = task.title
                priority = task.priority
                if let taskDeadline = task.deadline {
                    hasDeadline = true
                    deadline = taskDeadline
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        onSave(trimmedTitle, hasDeadline ? deadline : nil, priority)
        dismiss()
    }
}

#Preview {
    AddEditTaskView(category: .career, onSave: { _, _, _ in })
}
