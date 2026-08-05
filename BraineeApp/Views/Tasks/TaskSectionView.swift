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

    @State private var viewMode: TaskViewMode = .byDate
    @State private var showingAddTask = false
    @State private var editingTask: TaskItem?

    init(category: TaskCategory) {
        self.category = category
        let categoryRaw = category.rawValue
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.categoryRaw == categoryRaw },
            sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewMode {
                case .byDate:
                    TaskListByDateView(
                        tasks: tasks,
                        onToggle: toggleTask,
                        onDelete: deleteTasks,
                        onEdit: { editingTask = $0 }
                    )
                case .dayPlan:
                    TaskDayPlanView(
                        tasks: tasks,
                        onToggle: toggleTask,
                        onDelete: deleteTasks,
                        onEdit: { editingTask = $0 }
                    )
                }
            }
            .navigationTitle(category.title)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    viewModePicker
                }

                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
#else
                ToolbarItem(placement: .automatic) {
                    viewModePicker
                }

                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
#endif
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView(category: category) { title, deadline, priority in
                    addTask(title: title, deadline: deadline, priority: priority)
                }
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(category: category, task: task) { title, deadline, priority in
                    updateTask(task, title: title, deadline: deadline, priority: priority)
                }
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

    private func addTask(title: String, deadline: Date?, priority: TaskPriority) {
        let task = TaskItem(
            title: title,
            deadline: deadline,
            priority: priority,
            category: category
        )
        modelContext.insert(task)
    }

    private func updateTask(_ task: TaskItem, title: String, deadline: Date?, priority: TaskPriority) {
        task.title = title
        task.deadline = deadline
        task.priority = priority
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                HapticFeedback.success()
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet, in sectionTasks: [TaskItem]) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sectionTasks[index])
            }
        }
    }
}

#Preview {
    TaskSectionView(category: .career)
        .modelContainer(for: TaskItem.self, inMemory: true)
}
