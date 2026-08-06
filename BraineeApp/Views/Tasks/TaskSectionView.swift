//
//  TaskSectionView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData

enum TaskViewMode: String, CaseIterable, Identifiable {
    case byDate = "По дате"
    case dayPlan = "План на день"

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
    @State private var newGroupName = ""

    init(category: TaskCategory) {
        self.category = category
        let categoryRaw = category.rawValue
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.categoryRaw == categoryRaw },
            sort: [SortDescriptor(\TaskItem.sortOrder)]
        )
        _groups = Query(
            filter: #Predicate<TaskGroup> { $0.categoryRaw == categoryRaw },
            sort: [SortDescriptor(\TaskGroup.sortOrder)]
        )
    }

    var body: some View {
        NavigationStack {
            TaskOrganizedListView(
                groups: groups,
                tasks: tasks,
                viewMode: viewMode,
                onToggle: toggleTask,
                onDelete: deleteTask,
                onEdit: { editingTask = $0 },
                onDeleteGroup: deleteGroup
            )
            .navigationTitle(category.title)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    viewModePicker
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    createGroupButton
                    addButton
                }
#else
                ToolbarItem(placement: .automatic) {
                    viewModePicker
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    createGroupButton
                    addButton
                }
#endif
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView(creationCategory: category) { formData in
                    addTask(formData)
                }
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(creationCategory: category, task: task) { formData in
                    updateTask(task, formData: formData)
                }
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
        }
    }

    private var viewModePicker: some View {
        Picker("Режим", selection: $viewMode) {
            ForEach(TaskViewMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
    }

    private var addButton: some View {
        Button {
            showingAddTask = true
        } label: {
            Image(systemName: "plus")
        }
    }

    private var createGroupButton: some View {
        Button {
            showingCreateGroup = true
        } label: {
            Image(systemName: "folder.badge.plus")
        }
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
            modelContext.delete(task)
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
