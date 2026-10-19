//
//  TaskRowView.swift
//  BraineeApp
//
//  Строка задачи: чекбокс, название, meta; опционально изменить/удалить.
//  Просроченные подсвечиваются бледно-красным фоном.

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var displaySettings: TaskListDisplaySettings = .default
    var showsActionButtons: Bool = false
    var onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let overdue = !task.isCompleted && task.isOverdue(at: context.date)
            HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(
                            task.isCompleted
                                ? DesignSystem.Colors.accent
                                : (overdue ? DesignSystem.Colors.danger : DesignSystem.Colors.textSecondary)
                        )
                        .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                .accessibilityLabel(task.isCompleted ? "Снять выполнение" : "Отметить выполненной")

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
                        metaRow(now: context.date, overdue: overdue)
                    }
                }

                Spacer(minLength: DesignSystem.Space.x2)

                if showsActionButtons {
                    HStack(spacing: 0) {
                        if let onEdit {
                            IconTapButton(
                                systemName: DesignSystem.Icon.pencil,
                                tint: DesignSystem.Colors.accent,
                                compact: true,
                                accessibilityLabel: "Изменить задачу"
                            ) {
                                onEdit()
                            }
                        }
                        if let onDelete {
                            IconTapButton(
                                systemName: DesignSystem.Icon.trash,
                                tint: DesignSystem.Colors.accent,
                                compact: true,
                                accessibilityLabel: "Удалить задачу"
                            ) {
                                onDelete()
                            }
                        }
                    }
                    .padding(.top, -2)
                }
            }
            .opacity(task.isCompleted ? 0.55 : 1)
            .padding(.vertical, overdue ? DesignSystem.Space.x1 : 0)
            .padding(.horizontal, overdue ? DesignSystem.Space.x1 : 0)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(overdue ? DesignSystem.Colors.dangerSoft : Color.clear)
            )
        }
    }

    private var hasMeta: Bool {
        (displaySettings.showDeadline && task.deadline != nil)
            || displaySettings.showStatus
            || displaySettings.showPriority
            || (displaySettings.showTags && !task.tags.isEmpty)
    }

    private func metaRow(now: Date, overdue: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Space.x1) {
                if displaySettings.showDeadline, let text = task.deadlineDisplayText {
                    MetaChip(
                        text: text,
                        foreground: overdue
                            ? DesignSystem.Colors.danger
                            : DesignSystem.Colors.textSecondary,
                        background: overdue
                            ? DesignSystem.Colors.danger.opacity(0.12)
                            : DesignSystem.Colors.chip
                    )
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
    var background: Color = DesignSystem.Colors.chip

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
                    .fill(background)
            )
    }
}

#Preview {
    GroupedCard {
        TaskRowView(
            task: TaskItem(
                title: "Подготовить презентацию",
                deadline: Calendar.current.date(byAdding: .day, value: -1, to: .now),
                hasDeadlineTime: true,
                priority: .highest,
                taskDetails: "Слайды и тезисы"
            ),
            showsActionButtons: true,
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
        .padding(DesignSystem.Space.x4)
    }
    .padding(DesignSystem.Space.x4)
    .appScreenBackground()
    .modelContainer(for: TaskItem.self, inMemory: true)
}
