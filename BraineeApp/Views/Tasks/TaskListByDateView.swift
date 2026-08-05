//
//  TaskListByDateView.swift
//  BraineeApp
//

import SwiftUI

struct TaskListByDateView: View {
    let tasks: [TaskItem]
    var onToggle: (TaskItem) -> Void
    var onDelete: (IndexSet, [TaskItem]) -> Void
    var onEdit: (TaskItem) -> Void

    private var groupedTasks: [(title: String, tasks: [TaskItem])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var overdue: [TaskItem] = []
        var todayTasks: [TaskItem] = []
        var tomorrowTasks: [TaskItem] = []
        var laterTasks: [TaskItem] = []
        var noDateTasks: [TaskItem] = []

        for task in tasks {
            guard let deadline = task.deadline else {
                noDateTasks.append(task)
                continue
            }

            let day = calendar.startOfDay(for: deadline)

            if task.isOverdue {
                overdue.append(task)
            } else if day == today {
                todayTasks.append(task)
            } else if day == tomorrow {
                tomorrowTasks.append(task)
            } else if day > tomorrow {
                laterTasks.append(task)
            } else {
                noDateTasks.append(task)
            }
        }

        let sortByPriority: (TaskItem, TaskItem) -> Bool = { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.createdAt > rhs.createdAt
        }

        var sections: [(title: String, tasks: [TaskItem])] = []

        if !overdue.isEmpty {
            sections.append(("Просрочено", overdue.sorted(by: sortByPriority)))
        }
        if !todayTasks.isEmpty {
            sections.append(("Сегодня", todayTasks.sorted(by: sortByPriority)))
        }
        if !tomorrowTasks.isEmpty {
            sections.append(("Завтра", tomorrowTasks.sorted(by: sortByPriority)))
        }
        if !laterTasks.isEmpty {
            sections.append(("Позже", laterTasks.sorted(by: sortByPriority)))
        }
        if !noDateTasks.isEmpty {
            sections.append(("Без даты", noDateTasks.sorted(by: sortByPriority)))
        }

        return sections
    }

    var body: some View {
        if tasks.isEmpty {
            EmptyTasksView()
        } else {
            List {
                ForEach(groupedTasks, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.tasks) { task in
                            TaskRowView(task: task) {
                                onToggle(task)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEdit(task)
                            }
                        }
                        .onDelete { offsets in
                            onDelete(offsets, section.tasks)
                        }
                    }
                }
            }
            .taskListStyle()
        }
    }
}

struct EmptyTasksView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Нет задач", systemImage: "checklist")
        } description: {
            Text("Нажмите «+», чтобы добавить первую задачу")
        }
    }
}

#Preview {
    TaskListByDateView(tasks: [], onToggle: { _ in }, onDelete: { _, _ in }, onEdit: { _ in })
}
