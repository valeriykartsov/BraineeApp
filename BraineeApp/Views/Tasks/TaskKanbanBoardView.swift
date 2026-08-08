//
//  TaskKanbanBoardView.swift
//  BraineeApp
//
//  Канбан: три колонки по статусу и drag-and-drop между колонками.
//  Сортировка вынесена в панель управления экрана «Задачи».

import SwiftUI

struct TaskKanbanBoardView: View {
    let tasks: [TaskItem]
    var displaySettings: TaskListDisplaySettings = .default
    var sortMode: KanbanSortMode

    var onToggle: (TaskItem) -> Void
    var onEdit: (TaskItem) -> Void
    var onDelete: (TaskItem) -> Void
    var onStatusChange: (TaskItem, TaskStatus) -> Void

    @State private var dropTargetStatus: TaskStatus?

    var body: some View {
        GeometryReader { geo in
            let bottomInset = DesignSystem.Space.x3
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                    ForEach(TaskStatus.allCases) { status in
                        column(
                            for: status,
                            height: max(geo.size.height - DesignSystem.Space.x2 - bottomInset, 280)
                        )
                    }
                }
                .groupedScreenPadding()
                .padding(.top, DesignSystem.Space.x2 + 2)
                .padding(.bottom, bottomInset)
            }
        }
        .padding(.bottom, DesignSystem.Space.x2)
        .appScreenBackground()
    }

    private func column(for status: TaskStatus, height: CGFloat) -> some View {
        let items = sortedTasks(in: status)
        let isTargeted = dropTargetStatus == status
        let shape = RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(status.title)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(items.count)")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)

            InsetDivider(leading: DesignSystem.Space.x3)

            ScrollView {
                LazyVStack(spacing: DesignSystem.Space.x2) {
                    if items.isEmpty {
                        Text("Перетащите сюда")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.Space.x3)
                    } else {
                        ForEach(items, id: \.uuid) { task in
                            kanbanCard(task)
                        }
                    }
                }
                .padding(DesignSystem.Space.x2)
            }
        }
        .frame(width: 260, height: height, alignment: .top)
        .background(shape.fill(DesignSystem.Colors.surface))
        .overlay(
            shape.strokeBorder(
                isTargeted ? DesignSystem.Colors.accent : .clear,
                lineWidth: DesignSystem.Stroke.emphasis
            )
        )
        .contentShape(shape)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: String.self) { items, _ in
            move(items, to: status)
        } isTargeted: { hovering in
            if hovering {
                dropTargetStatus = status
            } else if dropTargetStatus == status {
                dropTargetStatus = nil
            }
        }
    }

    private func kanbanCard(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Space.x1) {
            TaskRowView(task: task, displaySettings: displaySettings) {
                onToggle(task)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit(task) }
            .contextMenu {
                Button("Редактировать") { onEdit(task) }
                Button("Удалить", role: .destructive) { onDelete(task) }
            }

            Image(systemName: DesignSystem.Icon.drag)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.75))
                .frame(width: 28, height: 36)
                .contentShape(Rectangle())
                .draggable(task.uuid.uuidString) {
                    Text(task.title)
                        .font(DesignSystem.Typography.body(15))
                        .padding(DesignSystem.Space.x3)
                        .frame(width: 220, alignment: .leading)
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                }
        }
        .padding(.horizontal, DesignSystem.Space.x2)
        .padding(.vertical, DesignSystem.Space.x2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(DesignSystem.Colors.background)
        )
    }

    private func sortedTasks(in status: TaskStatus) -> [TaskItem] {
        let filtered = tasks.filter { $0.status == status }
        switch sortMode {
        case .priority:
            return filtered.sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .title:
            return filtered.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    @discardableResult
    private func move(_ items: [String], to status: TaskStatus) -> Bool {
        guard let raw = items.first,
              let id = UUID(uuidString: raw),
              let task = tasks.first(where: { $0.uuid == id }) else {
            return false
        }
        guard task.status != status else { return false }
        HapticFeedback.success()
        onStatusChange(task, status)
        dropTargetStatus = nil
        return true
    }
}
