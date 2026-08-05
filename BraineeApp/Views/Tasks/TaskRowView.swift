//
//  TaskRowView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let deadline = task.deadline {
                        Label(deadline.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    PriorityBadge(priority: task.priority)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(task.isCompleted ? 0.7 : 1)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(PriorityStyle.color(for: priority).opacity(0.15))
            .foregroundStyle(PriorityStyle.color(for: priority))
            .clipShape(Capsule())
    }
}

#Preview {
    List {
        TaskRowView(
            task: TaskItem(title: "Подготовить презентацию", deadline: .now, priority: .high, category: .career),
            onToggle: {}
        )
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
