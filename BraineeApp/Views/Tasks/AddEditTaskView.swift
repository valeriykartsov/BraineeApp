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
    private var detailsLimit: Int { TaskInputValidation.detailsMaxLength }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                        .font(DesignSystem.Typography.body())

                    if isEditing {
                        Picker("Тип", selection: $category) {
                            ForEach(TaskCategory.allCases) { cat in
                                Label(cat.title, systemImage: cat.systemImage)
                                    .tag(cat)
                            }
                        }
                    }
                } header: {
                    Text("Задача")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)

                Section {
                    TextField("Описание", text: $taskDetails, axis: .vertical)
                        .font(DesignSystem.Typography.body())
                        .lineLimit(3...6)
                        .onChange(of: taskDetails) { _, newValue in
                            if newValue.count > detailsLimit {
                                taskDetails = String(newValue.prefix(detailsLimit))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(taskDetails.count)/\(detailsLimit)")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(
                                taskDetails.count >= detailsLimit
                                    ? DesignSystem.Colors.danger
                                    : DesignSystem.Colors.accent
                            )
                    }
                } header: {
                    Text("Описание")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)

                Section {
                    Toggle("Указать дату", isOn: $hasDeadline)
                        .tint(DesignSystem.Colors.accent)

                    if hasDeadline {
                        DatePicker(
                            "Дата исполнения",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                        .tint(DesignSystem.Colors.accent)
                    }
                } header: {
                    Text("Дедлайн")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)

                Section {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases) { level in
                            HStack {
                                Circle()
                                    .fill(PriorityStyle.color(for: level))
                                    .frame(width: DesignSystem.Space.x2, height: DesignSystem.Space.x2)
                                Text(level.title)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Приоритет")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)

                Section {
                    if allTags.isEmpty {
                        Text("В библиотеке пока нет тегов. Добавьте их в Профиле.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    } else {
                        ForEach(allTags) { tag in
                            let isSelected = selectedTagIDs.contains(tag.persistentModelID)
                            Button {
                                toggleTag(tag)
                            } label: {
                                HStack(spacing: DesignSystem.Space.x3) {
                                    Image(systemName: DesignSystem.Icon.tag)
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                    Text(tag.name)
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                    }
                                }
                            }
                            .listRowBackground(DesignSystem.Colors.surface)
                        }
                    }
                } header: {
                    Text("Теги")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                } footer: {
                    Text("Нажмите тег в списке, чтобы добавить или убрать его с задачи.")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                if isEditing {
                    Section {
                        Button("Удалить задачу", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                    .listRowBackground(DesignSystem.Colors.surface)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .tint(DesignSystem.Colors.accent)
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
                        .disabled(!TaskInputValidation.canSaveTitle(title))
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
        guard TaskInputValidation.canSaveTitle(title) else { return }

        let selectedTags = allTags.filter { selectedTagIDs.contains($0.persistentModelID) }
        let formData = TaskFormData(
            title: TaskInputValidation.normalizedTitle(title),
            deadline: hasDeadline ? deadline : nil,
            priority: priority,
            category: isEditing ? category : creationCategory,
            taskDetails: TaskInputValidation.clampedDetails(taskDetails),
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
