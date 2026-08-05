//
//  TaskDayPlanView.swift
//  BraineeApp
//

import SwiftUI

struct TaskDayPlanView: View {
    let tasks: [TaskItem]
    var onToggle: (TaskItem) -> Void
    var onDelete: (IndexSet, [TaskItem]) -> Void
    var onEdit: (TaskItem) -> Void

    private var todayTasks: [TaskItem] {
        tasks
            .filter { $0.isDueToday }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted && rhs.isCompleted
                }
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var body: some View {
        if todayTasks.isEmpty {
            ContentUnavailableView {
                Label("План на день пуст", systemImage: "sun.max")
            } description: {
                Text("Добавьте задачи с дедлайном на сегодня")
            }
        } else {
            List {
                Section("Сегодня") {
                    ForEach(todayTasks) { task in
                        TaskRowView(task: task) {
                            onToggle(task)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onEdit(task)
                        }
                    }
                    .onDelete { offsets in
                        onDelete(offsets, todayTasks)
                    }
                }
            }
            .taskListStyle()
        }
    }
}

#Preview {
    TaskDayPlanView(tasks: [], onToggle: { _ in }, onDelete: { _, _ in }, onEdit: { _ in })
}
