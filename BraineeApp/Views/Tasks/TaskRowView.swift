//
//  TaskRowView.swift
//  BraineeApp
//
//  Строка задачи: название + компактная meta-строка (дедлайн, статус, приоритет, теги).

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

                if hasMeta {
                    metaRow
                }
            }

            Spacer(minLength: DesignSystem.Space.x2)
        }
        .opacity(task.isCompleted ? 0.55 : 1)
    }

    private var hasMeta: Bool {
        (displaySettings.showDeadline && task.deadline != nil)
            || displaySettings.showStatus
            || displaySettings.showPriority
            || (displaySettings.showTags && !task.tags.isEmpty)
    }

    private var metaRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Space.x1) {
                if displaySettings.showDeadline, let text = task.deadlineDisplayText {
                    // Периодическое обновление: просрочка по времени появляется без перезапуска экрана.
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        MetaChip(
                            text: text,
                            foreground: task.isOverdue(at: context.date)
                                ? DesignSystem.Colors.danger
                                : DesignSystem.Colors.textSecondary
                        )
                    }
                }

                if displaySettings.showStatus {
                    MetaChip(
                        text: task.status.title,
                        foreground: DesignSystem.Colors.accent
                    )
                }

                if displaySettings.showPriority {
                    MetaChip(
                        text: task.priority.title,
                        foreground: PriorityStyle.color(for: task.priority)
                    )
                }

                if displaySettings.showTags {
                    ForEach(task.tags.prefix(3), id: \.uuid) { tag in
                        MetaChip(
                            text: tag.name,
                            foreground: DesignSystem.Colors.textSecondary
                        )
                    }
                }
            }
        }
    }
}

/// Чип meta-поля на серой подложке — как теги в других разделах.
private struct MetaChip: View {
    let text: String
    let foreground: Color

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption(12))
            .fontWeight(.medium)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, DesignSystem.Space.x2)
            .padding(.vertical, DesignSystem.Space.x1)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignSystem.Colors.chip)
            )
    }
}

#Preview {
    GroupedCard {
        TaskRowView(
            task: TaskItem(
                title: "Подготовить презентацию",
                deadline: .now,
                hasDeadlineTime: true,
                priority: .highest,
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
