//
//  TaskOrganizedListView.swift
//  BraineeApp
//
//  Список задач по группам с drag-and-drop: карточки папок и секция «Без папки».

import SwiftUI
import SwiftData

struct TaskOrganizedListView: View {
    @Environment(\.modelContext) private var modelContext

    let groups: [TaskGroup]
    let tasks: [TaskItem]
    let viewMode: TaskViewMode

    var onToggle: (TaskItem) -> Void
    var onDelete: (TaskItem) -> Void
    var onEdit: (TaskItem) -> Void
    var onDeleteGroup: (TaskGroup) -> Void

    @State private var dropTargetGroupUUID: UUID?

    private var visibleTasks: [TaskItem] {
        let active = tasks.filter { !$0.isSoftDeleted }
        switch viewMode {
        case .dayPlan:
            return active.filter(\.isDueToday)
        case .byDate:
            return active
        }
    }

    private var sortedGroups: [TaskGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var ungroupedTasks: [TaskItem] {
        sortedTasks(visibleTasks.filter { $0.group == nil })
    }

    private var ungroupedDropID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    var body: some View {
        if visibleTasks.isEmpty && sortedGroups.isEmpty && viewMode == .dayPlan {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedGroups) { group in
                        let groupTasks = sortedTasks(
                            visibleTasks.filter { $0.group?.uuid == group.uuid }
                        )
                        if !groupTasks.isEmpty || viewMode == .byDate {
                            groupFolderCard(group: group, tasks: groupTasks)
                        }
                    }

                    if viewMode == .byDate || !ungroupedTasks.isEmpty {
                        ungroupedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewMode {
        case .dayPlan:
            ContentUnavailableView {
                Label("План на день пуст", systemImage: "sun.max")
            } description: {
                Text("Добавьте задачи с дедлайном на сегодня")
            }
        case .byDate:
            EmptyTasksView()
        }
    }

    private func groupFolderCard(group: TaskGroup, tasks groupTasks: [TaskItem]) -> some View {
        let isTargeted = dropTargetGroupUUID == group.uuid

        return VStack(alignment: .leading, spacing: 0) {
            groupHeader(group, taskCount: groupTasks.count)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if groupTasks.isEmpty && viewMode == .byDate {
                emptyFolderHint(name: group.name)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(groupTasks) { task in
                        taskRow(task)
                        if task.uuid != groupTasks.last?.uuid {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: String.self) { items, _ in
            performDrop(items, into: group)
        } isTargeted: { isTargeted in
            if isTargeted {
                dropTargetGroupUUID = group.uuid
            } else if dropTargetGroupUUID == group.uuid {
                dropTargetGroupUUID = nil
            }
        }
    }

    private var ungroupedSection: some View {
        let isTargeted = dropTargetGroupUUID == ungroupedDropID

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "tray")
                    .foregroundStyle(.secondary)
                Text("Без папки")
                    .font(.headline)
                if !ungroupedTasks.isEmpty {
                    Text("\(ungroupedTasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if ungroupedTasks.isEmpty && viewMode == .byDate {
                emptyFolderHint(name: nil)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(ungroupedTasks) { task in
                        taskRow(task)
                        if task.uuid != ungroupedTasks.last?.uuid {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: String.self) { items, _ in
            performDrop(items, into: nil)
        } isTargeted: { isTargeted in
            if isTargeted {
                dropTargetGroupUUID = ungroupedDropID
            } else if dropTargetGroupUUID == ungroupedDropID {
                dropTargetGroupUUID = nil
            }
        }
    }

    private func emptyFolderHint(name: String?) -> some View {
        HStack {
            Spacer(minLength: 0)
            Label {
                if let name {
                    Text("Перетащите в «\(name)»")
                } else {
                    Text("Перетащите сюда")
                }
            } icon: {
                Image(systemName: "arrow.down.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func groupHeader(_ group: TaskGroup, taskCount: Int) -> some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(group.name)
                .font(.headline)
            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                onDeleteGroup(group)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            TaskRowView(task: task) {
                onToggle(task)
            }

            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Перетащить задачу")
                .draggable(task.uuid.uuidString)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit(task)
        }
        .contextMenu {
            Button {
                onEdit(task)
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(task)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func sortedTasks(_ items: [TaskItem]) -> [TaskItem] {
        switch viewMode {
        case .byDate:
            items.sorted(by: TaskSortHelper.byDateMode)
        case .dayPlan:
            items.sorted(by: TaskSortHelper.byDayPlan)
        }
    }

    @discardableResult
    /// Обрабатывает drop-жест: находит задачу по UUID и передаёт в assignTask.
    private func performDrop(_ items: [String], into group: TaskGroup?) -> Bool {
        guard let task = TaskDragPayload.task(in: tasks, from: items) else { return false }
        assignTask(task, to: group)
        return true
    }

    /// Переносит задачу в группу (или в «Без папки», если group == nil) и сохраняет JSON.
    private func assignTask(_ task: TaskItem, to group: TaskGroup?) {
        guard !task.isSoftDeleted else { return }

        withAnimation {
            task.group = group
            let targetTasks = visibleTasks.filter { item in
                guard item.uuid != task.uuid else { return false }
                if let group {
                    return item.group?.uuid == group.uuid
                }
                return item.group == nil
            }
            task.sortOrder = (targetTasks.map(\.sortOrder).max() ?? -1) + 1
            modelContext.persistToJSON()
        }
    }
}
