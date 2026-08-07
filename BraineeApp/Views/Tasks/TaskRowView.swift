//
//  TaskRowView.swift
//  BraineeApp
//
//  Строка задачи: название как у папки + опциональные поля по настройкам отображения.

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var displaySettings: TaskListDisplaySettings = .default
    var onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                // Шрифт как у названия папки (body 16).
                Text(task.title)
                    .font(DesignSystem.Typography.body(16))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.textPrimary
                    )
                    .multilineTextAlignment(.leading)

                if displaySettings.showDetails, !task.taskDetails.isEmpty {
                    Text(task.taskDetails)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                if displaySettings.showDeadline, let deadline = task.deadline {
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(
                            task.isOverdue
                                ? DesignSystem.Colors.danger
                                : DesignSystem.Colors.textSecondary
                        )
                }

                if displaySettings.showPriority || displaySettings.showTags {
                    trailingMeta
                }
            }

            Spacer(minLength: DesignSystem.Space.x2)
        }
        .opacity(task.isCompleted ? 0.55 : 1)
    }

    @ViewBuilder
    private var trailingMeta: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            if displaySettings.showPriority {
                Text(task.priority.title)
                    .font(DesignSystem.Typography.caption(12))
                    .fontWeight(.medium)
                    .foregroundStyle(PriorityStyle.color(for: task.priority))
            }

            if displaySettings.showTags, let firstTag = task.tags.first {
                Text(firstTag.name)
                    .font(DesignSystem.Typography.caption(12))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    GroupedCard {
        TaskRowView(
            task: TaskItem(
                title: "Подготовить презентацию",
                deadline: .now,
                priority: .highest,
                category: .career,
                taskDetails: "Слайды и тезисы"
            ),
            onToggle: {}
        )
        .padding(DesignSystem.Space.x4)
    }
    .padding(DesignSystem.Space.x4)
    .appScreenBackground()
    .modelContainer(for: TaskItem.self, inMemory: true)
}
