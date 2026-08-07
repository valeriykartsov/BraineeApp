//
//  TaskOrganizedListView.swift
//  BraineeApp
//
//  Список задач в inset-grouped карточках (референс Settings / Telegram).

import SwiftUI
import SwiftData

struct TaskOrganizedListView: View {
    @Environment(\.modelContext) private var modelContext

    let groups: [TaskGroup]
    let tasks: [TaskItem]
    let viewMode: TaskViewMode
    var displaySettings: TaskListDisplaySettings = .default

    var onToggle: (TaskItem) -> Void
    var onDelete: (TaskItem) -> Void
    var onEdit: (TaskItem) -> Void
    var onDeleteGroup: (TaskGroup) -> Void

    @State private var dropTargetGroupUUID: UUID?
    @State private var editingGroupUUID: UUID?
    @State private var editingGroupName = ""
    @State private var groupPendingDeletion: TaskGroup?
    @State private var showingDeleteGroupConfirm = false

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

    private var dayPlanTasks: [TaskItem] {
        sortedTasks(visibleTasks)
    }

    private var ungroupedDropID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    var body: some View {
        Group {
            switch viewMode {
            case .dayPlan:
                dayPlanContent
            case .byDate:
                byDateContent
            }
        }
        .appScreenBackground()
        .alert("Удалить группу?", isPresented: $showingDeleteGroupConfirm) {
            Button("Отмена", role: .cancel) {
                groupPendingDeletion = nil
            }
            Button("Удалить", role: .destructive) {
                if let group = groupPendingDeletion {
                    onDeleteGroup(group)
                }
                groupPendingDeletion = nil
            }
        } message: {
            if let name = groupPendingDeletion?.name {
                Text("Группа «\(name)» будет удалена. Задачи из неё останутся в «Без папки».")
            } else {
                Text("Задачи из группы останутся в «Без папки».")
            }
        }
    }

    @ViewBuilder
    private var dayPlanContent: some View {
        if dayPlanTasks.isEmpty {
            emptyState
        } else {
            ScrollView {
                GroupedSection(title: "Сегодня") {
                    taskStack(dayPlanTasks)
                }
                .groupedScreenPadding()
                .padding(.vertical, DesignSystem.Space.x2 + 2)
            }
        }
    }

    @ViewBuilder
    private var byDateContent: some View {
        if visibleTasks.isEmpty && sortedGroups.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Space.sectionGap) {
                    ForEach(sortedGroups) { group in
                        let groupTasks = sortedTasks(
                            visibleTasks.filter { $0.group?.uuid == group.uuid }
                        )
                        groupSection(group: group, tasks: groupTasks)
                    }

                    ungroupedSection
                }
                .groupedScreenPadding()
                .padding(.vertical, DesignSystem.Space.x2 + 2)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewMode {
        case .dayPlan:
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                GroupedSection(title: "Сегодня") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                        Text("На сегодня задач нет")
                            .font(DesignSystem.Typography.headline())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("Добавьте задачи с дедлайном на сегодня")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Space.x4)
                }
            }
            .groupedScreenPadding()
            .padding(.vertical, DesignSystem.Space.x4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .byDate:
            EmptyTasksView()
        }
    }

    private func groupSection(group: TaskGroup, tasks groupTasks: [TaskItem]) -> some View {
        let isTargeted = dropTargetGroupUUID == group.uuid

        return GroupedSection(title: nil) {
            VStack(alignment: .leading, spacing: 0) {
                groupHeader(group, taskCount: groupTasks.count)
                InsetDivider(leading: DesignSystem.Space.rowIconInset)

                if groupTasks.isEmpty {
                    emptyFolderHint(name: group.name)
                        .padding(.horizontal, DesignSystem.Space.x3)
                        .padding(.vertical, DesignSystem.Space.x2 + 2)
                } else {
                    taskStack(groupTasks)
                }
            }
            .flatHighlight(highlighted: isTargeted)
        }
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

        return GroupedSection(title: nil) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DesignSystem.Space.x2) {
                    Image(systemName: DesignSystem.Icon.tray)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    Text("Без папки")
                        .font(DesignSystem.Typography.body(16))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    if !ungroupedTasks.isEmpty {
                        Text("\(ungroupedTasks.count)")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2 + 2)

                if ungroupedTasks.isEmpty && viewMode == .byDate {
                    InsetDivider(leading: DesignSystem.Space.rowIconInset)
                    emptyFolderHint(name: nil)
                        .padding(.horizontal, DesignSystem.Space.x3)
                        .padding(.vertical, DesignSystem.Space.x2 + 2)
                } else if !ungroupedTasks.isEmpty {
                    InsetDivider(leading: DesignSystem.Space.rowIconInset)
                    taskStack(ungroupedTasks)
                }
            }
            .flatHighlight(highlighted: isTargeted)
        }
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
        Text(name.map { "Перетащите в «\($0)»" } ?? "Перетащите сюда")
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func groupHeader(_ group: TaskGroup, taskCount: Int) -> some View {
        if editingGroupUUID == group.uuid {
            HStack(spacing: DesignSystem.Space.x2) {
                Image(systemName: DesignSystem.Icon.folder)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                TextField("Название группы", text: $editingGroupName)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                IconTapButton(
                    systemName: DesignSystem.Icon.check,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Подтвердить название"
                ) {
                    confirmRenameGroup(group)
                }
                .disabled(!TaskInputValidation.canSaveGroupName(editingGroupName))

                IconTapButton(
                    systemName: DesignSystem.Icon.cancel,
                    tint: DesignSystem.Colors.textSecondary,
                    compact: true,
                    accessibilityLabel: "Отменить редактирование"
                ) {
                    cancelRenameGroup()
                }
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
        } else {
            HStack(spacing: DesignSystem.Space.x2) {
                Image(systemName: DesignSystem.Icon.folder)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                Text(group.name)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer(minLength: DesignSystem.Space.x2)
                HStack(spacing: 0) {
                    IconTapButton(
                        systemName: DesignSystem.Icon.pencil,
                        tint: DesignSystem.Colors.accent,
                        compact: true,
                        accessibilityLabel: "Редактировать название группы"
                    ) {
                        beginRenameGroup(group)
                    }
                    IconTapButton(
                        systemName: DesignSystem.Icon.trash,
                        tint: DesignSystem.Colors.accent,
                        compact: true,
                        accessibilityLabel: "Удалить группу"
                    ) {
                        groupPendingDeletion = group
                        showingDeleteGroupConfirm = true
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
        }
    }

    private func beginRenameGroup(_ group: TaskGroup) {
        editingGroupUUID = group.uuid
        editingGroupName = group.name
    }

    private func cancelRenameGroup() {
        editingGroupUUID = nil
        editingGroupName = ""
    }

    private func confirmRenameGroup(_ group: TaskGroup) {
        guard TaskInputValidation.canSaveGroupName(editingGroupName) else { return }
        group.name = TaskInputValidation.normalizedGroupName(editingGroupName)
        modelContext.persistToJSON()
        cancelRenameGroup()
    }

    private func taskStack(_ items: [TaskItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.uuid) { index, task in
                taskRow(task)
                if index < items.count - 1 {
                    InsetDivider(leading: DesignSystem.Space.rowIconInset)
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            TaskRowView(task: task, displaySettings: displaySettings) {
                onToggle(task)
            }

            Image(systemName: DesignSystem.Icon.drag)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.7))
                .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x6)
                .contentShape(Rectangle())
                .accessibilityLabel("Открыть задачу")
                .draggable(task.uuid.uuidString)
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2 + 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit(task)
        }
        .contextMenu {
            Button {
                onEdit(task)
            } label: {
                Label("Редактировать", systemImage: DesignSystem.Icon.pencil)
            }
            Button(role: .destructive) {
                onDelete(task)
            } label: {
                Label("Удалить", systemImage: DesignSystem.Icon.trash)
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
    private func performDrop(_ items: [String], into group: TaskGroup?) -> Bool {
        guard let task = TaskDragPayload.task(in: tasks, from: items) else { return false }
        assignTask(task, to: group)
        return true
    }

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
