//
//  TaskOrganizedListView.swift
//  BraineeApp
//

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

    private var visibleTasks: [TaskItem] {
        switch viewMode {
        case .dayPlan:
            tasks.filter(\.isDueToday)
        case .byDate:
            tasks
        }
    }

    private var sortedGroups: [TaskGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var ungroupedTasks: [TaskItem] {
        sortedTasks(visibleTasks.filter { $0.group == nil })
    }

    var body: some View {
        if visibleTasks.isEmpty && sortedGroups.isEmpty {
            emptyState
        } else {
            List {
                ForEach(sortedGroups) { group in
                    let groupTasks = sortedTasks(
                        visibleTasks.filter { $0.group?.persistentModelID == group.persistentModelID }
                    )
                    if !groupTasks.isEmpty || viewMode == .byDate {
                        Section {
                            ForEach(groupTasks) { task in
                                taskRow(task)
                            }
                            .onMove { source, destination in
                                moveTasks(in: groupTasks, group: group, from: source, to: destination)
                            }
                        } header: {
                            groupHeader(group, taskCount: groupTasks.count)
                        }
                        .dropDestination(for: TaskDragID.self) { items, _ in
                            handleTaskDrop(items, into: group)
                        }
                    }
                }
                .onMove { source, destination in
                    moveGroups(from: source, to: destination)
                }

                if !ungroupedTasks.isEmpty {
                    Section("Без группы") {
                        ForEach(ungroupedTasks) { task in
                            taskRow(task)
                        }
                        .onMove { source, destination in
                            moveTasks(in: ungroupedTasks, group: nil, from: source, to: destination)
                        }
                    }
                    .dropDestination(for: TaskDragID.self) { items, _ in
                        handleTaskDrop(items, into: nil)
                    }
                }
            }
            .taskListStyle()
#if os(iOS)
            .environment(\.editMode, .constant(.active))
#endif
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
        TaskRowView(task: task) {
            onToggle(task)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit(task)
        }
        .draggable(TaskDragID(uuid: task.uuid))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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

    private func handleTaskDrop(_ items: [TaskDragID], into group: TaskGroup?) -> Bool {
        guard let dragID = items.first,
              let dropped = TaskItem.fetch(byUUID: dragID.uuid, in: modelContext) else { return false }

        dropped.group = group
        let targetTasks = visibleTasks.filter {
            $0.group?.persistentModelID == group?.persistentModelID && $0.persistentModelID != dropped.persistentModelID
        }
        dropped.sortOrder = (targetTasks.map(\.sortOrder).max() ?? -1) + 1
        modelContext.persistToJSON()
        return true
    }

    private func moveTasks(in list: [TaskItem], group: TaskGroup?, from source: IndexSet, to destination: Int) {
        var reordered = list
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
            task.group = group
        }
        modelContext.persistToJSON()
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = sortedGroups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.sortOrder = index
        }
        modelContext.persistToJSON()
    }
}
