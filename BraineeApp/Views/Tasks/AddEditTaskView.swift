//
//  AddEditTaskView.swift
//  BraineeApp
//
//  Форма создания и редактирования задачи: название, дедлайн, приоритет, теги, удаление.

import SwiftUI
import SwiftData

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTag.name) private var allTags: [TaskTag]

    let creationCategory: TaskCategory
    var task: TaskItem?
    var onSave: (TaskFormData) -> Void
    var onDelete: ((TaskItem) -> Void)?

    @State private var title = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .career
    @State private var taskDetails = ""
    @State private var selectedTagIDs: Set<PersistentIdentifier> = []
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { task != nil }
    private var detailsLimit: Int { 200 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    TextField("Название", text: $title)

                    if isEditing {
                        Picker("Тип", selection: $category) {
                            ForEach(TaskCategory.allCases) { cat in
                                Label(cat.title, systemImage: cat.systemImage)
                                    .tag(cat)
                            }
                        }
                    }
                }

                Section {
                    TextField("Описание", text: $taskDetails, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: taskDetails) { _, newValue in
                            if newValue.count > detailsLimit {
                                taskDetails = String(newValue.prefix(detailsLimit))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(taskDetails.count)/\(detailsLimit)")
                            .font(.caption)
                            .foregroundStyle(taskDetails.count >= detailsLimit ? .red : .secondary)
                    }
                } header: {
                    Text("Описание")
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

                if !allTags.isEmpty {
                    Section("Теги") {
                        TagFlowLayout(spacing: 8) {
                            ForEach(allTags) { tag in
                                TagChipView(
                                    name: tag.name,
                                    isSelected: selectedTagIDs.contains(tag.persistentModelID)
                                ) {
                                    toggleTag(tag)
                                }
                            }
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("Удалить задачу", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
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
            .alert("Удалить задачу?", isPresented: $showingDeleteConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    guard let task else { return }
                    onDelete?(task)
                    dismiss()
                }
            } message: {
                Text("Задача будет перемещена в «Удалённые задачи» в профиле.")
            }
            .onAppear {
                category = creationCategory
                guard let task else { return }
                title = task.title
                priority = task.priority
                category = task.category
                taskDetails = task.taskDetails
                selectedTagIDs = Set(task.tags.map(\.persistentModelID))
                if let taskDeadline = task.deadline {
                    hasDeadline = true
                    deadline = taskDeadline
                }
            }
        }
    }

    private func toggleTag(_ tag: TaskTag) {
        let id = tag.persistentModelID
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let selectedTags = allTags.filter { selectedTagIDs.contains($0.persistentModelID) }
        let formData = TaskFormData(
            title: trimmedTitle,
            deadline: hasDeadline ? deadline : nil,
            priority: priority,
            category: isEditing ? category : creationCategory,
            taskDetails: taskDetails.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedTags: selectedTags
        )
        onSave(formData)
        dismiss()
    }
}

#Preview {
    AddEditTaskView(creationCategory: .career, onSave: { _ in })
        .modelContainer(for: [TaskItem.self, TaskTag.self], inMemory: true)
}
