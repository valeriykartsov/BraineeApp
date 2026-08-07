//
//  TaskRowView.swift
//  BraineeApp
//
//  Компактная строка задачи: контрастные дата/теги/приоритет на карточке.

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
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
                    .frame(width: DesignSystem.Space.x8, height: DesignSystem.Space.x8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Space.x1)

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                Text(task.title)
                    .font(DesignSystem.Typography.body(15))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.textPrimary
                    )

                if !task.taskDetails.isEmpty {
                    Text(task.taskDetails)
                        .font(DesignSystem.Typography.caption(11))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: DesignSystem.Space.x1) {
                    if let deadline = task.deadline {
                        HStack(spacing: DesignSystem.Space.x1) {
                            Image(systemName: DesignSystem.Icon.calendar)
                                .font(.system(size: 10, weight: .medium))
                            Text(deadline.formatted(date: .abbreviated, time: .omitted))
                                .font(DesignSystem.Typography.data(11))
                        }
                        .foregroundStyle(
                            task.isOverdue
                                ? DesignSystem.Colors.danger
                                : DesignSystem.Colors.textPrimary
                        )
                        .padding(.horizontal, DesignSystem.Space.x2)
                        .padding(.vertical, DesignSystem.Space.x1)
                        .background(DesignSystem.Colors.chip)
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                                .strokeBorder(
                                    task.isOverdue ? DesignSystem.Colors.danger : DesignSystem.Colors.divider,
                                    lineWidth: DesignSystem.Stroke.hairline
                                )
                        }
                    }

                    PriorityBadge(priority: task.priority)
                }

                if !task.tags.isEmpty {
                    TagFlowLayout(spacing: DesignSystem.Space.x1) {
                        ForEach(task.tags, id: \.persistentModelID) { tag in
                            TagChipView(name: tag.name)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .opacity(task.isCompleted ? 0.65 : 1)
    }
}

/// Компактный бейдж приоритета на chip-подложке.
struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.title)
            .font(DesignSystem.Typography.data(10))
            .padding(.horizontal, DesignSystem.Space.x2)
            .padding(.vertical, DesignSystem.Space.x1)
            .background(DesignSystem.Colors.chip)
            .foregroundStyle(PriorityStyle.color(for: priority))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                    .strokeBorder(PriorityStyle.color(for: priority), lineWidth: DesignSystem.Stroke.hairline)
            }
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
