//
//  TaskSectionView.swift
//  BraineeApp
//
//  Экран раздела задач: список, режимы просмотра, создание задач и групп.

import SwiftUI
import SwiftData

/// Режим отображения: все задачи или только на сегодня.
enum TaskViewMode: String, CaseIterable, Identifiable {
    case byDate = "Задачи"
    case dayPlan = "Сегодня"

    var id: String { rawValue }
}

struct TaskSectionView: View {
    @Environment(\.modelContext) private var modelContext

    let category: TaskCategory

    @Query private var tasks: [TaskItem]
    @Query private var groups: [TaskGroup]

    @State private var viewMode: TaskViewMode = .byDate
    @State private var showingAddTask = false
    @State private var editingTask: TaskItem?
    @State private var showingCreateGroup = false
    @State private var showingDisplaySettings = false
    @State private var newGroupName = ""
    @State private var displaySettings = TaskListDisplaySettings.load()

    init(category: TaskCategory) {
        self.category = category
        let categoryRaw = category.rawValue
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.categoryRaw == categoryRaw && !$0.isSoftDeleted },
            sort: [SortDescriptor(\TaskItem.sortOrder)]
        )
        _groups = Query(
            filter: #Predicate<TaskGroup> { $0.categoryRaw == categoryRaw },
            sort: [SortDescriptor(\TaskGroup.sortOrder)]
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(category.title)
                    .font(DesignSystem.Typography.title(24))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.top, DesignSystem.Space.x1)
                    .padding(.bottom, DesignSystem.Space.x2)

                sectionControlsBar
                    .padding(.bottom, DesignSystem.Space.x2)

                TaskOrganizedListView(
                    groups: groups,
                    tasks: tasks,
                    viewMode: viewMode,
                    displaySettings: displaySettings,
                    onToggle: toggleTask,
                    onDelete: deleteTask,
                    onEdit: { editingTask = $0 },
                    onDeleteGroup: deleteGroup
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .tint(DesignSystem.Colors.accent)
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView(creationCategory: category) { formData in
                    addTask(formData)
                }
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(
                    creationCategory: category,
                    task: task,
                    onSave: { formData in
                        updateTask(task, formData: formData)
                    },
                    onDelete: { taskToDelete in
                        deleteTask(taskToDelete)
                        editingTask = nil
                    }
                )
            }
            .sheet(isPresented: $showingDisplaySettings) {
                TaskListDisplaySettingsView(settings: $displaySettings)
            }
            .alert("Новая группа", isPresented: $showingCreateGroup) {
                TextField("Название группы", text: $newGroupName)
                Button("Отмена", role: .cancel) {
                    newGroupName = ""
                }
                Button("Создать") {
                    createGroup()
                }
            } message: {
                Text("Группа будет создана в разделе «\(category.title)»")
            }
            .onAppear {
                displaySettings = TaskListDisplaySettings.load()
            }
        }
    }

    private var sectionControlsBar: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            AppSegmentedControl(
                selection: $viewMode,
                options: TaskViewMode.allCases,
                title: { $0.rawValue }
            )
            .frame(maxWidth: .infinity)

            // Три кнопки одной ширины: настройки → группа → задача.
            HStack(spacing: DesignSystem.Space.x1) {
                toolbarIconButton(
                    systemName: "slider.horizontal.3",
                    label: "Настройка отображения"
                ) {
                    showingDisplaySettings = true
                }

                toolbarIconButton(
                    systemName: "folder.badge.plus",
                    label: "Создать группу"
                ) {
                    showingCreateGroup = true
                }

                toolbarIconButton(
                    systemName: "plus",
                    label: "Добавить задачу"
                ) {
                    showingAddTask = true
                }
            }
        }
        .foregroundStyle(DesignSystem.Colors.accent)
        .padding(.horizontal, DesignSystem.Space.screenInset)
    }

    private func toolbarIconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private func addTask(_ formData: TaskFormData) {
        let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TaskItem(
            title: formData.title,
            deadline: formData.deadline,
            priority: formData.priority,
            category: formData.category,
            taskDetails: formData.taskDetails,
            sortOrder: nextOrder,
            tags: formData.selectedTags
        )
        modelContext.insert(task)
        modelContext.persistToJSON()
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        task.title = formData.title
        task.deadline = formData.deadline
        task.priority = formData.priority
        task.category = formData.category
        task.taskDetails = formData.taskDetails
        task.tags = formData.selectedTags
        modelContext.persistToJSON()
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                HapticFeedback.success()
            }
            modelContext.persistToJSON()
        }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            task.isSoftDeleted = true
            task.deletedAt = .now
            try? modelContext.save()
            modelContext.persistToJSON()
        }
    }

    private func deleteGroup(_ group: TaskGroup) {
        withAnimation {
            for task in tasks where task.group?.persistentModelID == group.persistentModelID {
                task.group = nil
            }
            modelContext.delete(group)
            modelContext.persistToJSON()
        }
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (groups.map(\.sortOrder).max() ?? -1) + 1
        let group = TaskGroup(name: trimmed, category: category, sortOrder: nextOrder)
        modelContext.insert(group)
        newGroupName = ""
        modelContext.persistToJSON()
    }
}

#Preview {
    TaskSectionView(category: .career)
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self], inMemory: true)
}
