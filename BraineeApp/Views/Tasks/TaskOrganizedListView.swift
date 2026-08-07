//
//  TaskOrganizedListView.swift
//  BraineeApp
//
//  Список задач в геометрии Панкина: карточки 4pt, тонкие линии, сетка 4.

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
        .pankinScreenBackground()
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
                LazyVStack(spacing: 0) {
                    ForEach(dayPlanTasks) { task in
                        taskRow(task)
                        if task.uuid != dayPlanTasks.last?.uuid {
                            PankinDivider()
                                .padding(.leading, DesignSystem.Space.x4)
                        }
                    }
                }
                .pankinCard()
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2)
            }
        }
    }

    @ViewBuilder
    private var byDateContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Space.x2) {
                ForEach(sortedGroups) { group in
                    let groupTasks = sortedTasks(
                        visibleTasks.filter { $0.group?.uuid == group.uuid }
                    )
                    groupFolderCard(group: group, tasks: groupTasks)
                }

                ungroupedSection
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewMode {
        case .dayPlan:
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                Text("План на день пуст")
                    .font(DesignSystem.Typography.title(22))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Добавьте задачи с дедлайном на сегодня")
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                PankinDivider()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DesignSystem.Space.x4)
        case .byDate:
            EmptyTasksView()
        }
    }

    private func groupFolderCard(group: TaskGroup, tasks groupTasks: [TaskItem]) -> some View {
        let isTargeted = dropTargetGroupUUID == group.uuid

        return VStack(alignment: .leading, spacing: 0) {
            groupHeader(group, taskCount: groupTasks.count)
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2)

            PankinDivider()

            if groupTasks.isEmpty && viewMode == .byDate {
                emptyFolderHint(name: group.name)
                    .padding(.vertical, DesignSystem.Space.x2)
            } else {
                VStack(spacing: 0) {
                    ForEach(groupTasks) { task in
                        taskRow(task)
                        if task.uuid != groupTasks.last?.uuid {
                            PankinDivider()
                                .padding(.leading, DesignSystem.Space.x4)
                        }
                    }
                }
            }
        }
        .pankinCard(highlighted: isTargeted)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular))
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
            HStack(spacing: DesignSystem.Space.x2) {
                Image(systemName: DesignSystem.Icon.tray)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("Без папки")
                    .font(DesignSystem.Typography.headline())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                if !ungroupedTasks.isEmpty {
                    Text("\(ungroupedTasks.count)")
                        .font(DesignSystem.Typography.data(12))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2)

            PankinDivider()

            if ungroupedTasks.isEmpty && viewMode == .byDate {
                emptyFolderHint(name: nil)
                    .padding(.vertical, DesignSystem.Space.x2)
            } else {
                VStack(spacing: 0) {
                    ForEach(ungroupedTasks) { task in
                        taskRow(task)
                        if task.uuid != ungroupedTasks.last?.uuid {
                            PankinDivider()
                                .padding(.leading, DesignSystem.Space.x4)
                        }
                    }
                }
            }
        }
        .pankinCard(highlighted: isTargeted)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular))
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
            Text(name.map { "Перетащите в «\($0)»" } ?? "Перетащите сюда")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                        .strokeBorder(DesignSystem.Colors.divider, lineWidth: DesignSystem.Stroke.hairline)
                }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Space.x4)
    }

    @ViewBuilder
    private func groupHeader(_ group: TaskGroup, taskCount: Int) -> some View {
        if editingGroupUUID == group.uuid {
            HStack(spacing: DesignSystem.Space.x1) {
                Image(systemName: DesignSystem.Icon.folder)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                TextField("Название группы", text: $editingGroupName)
                    .font(DesignSystem.Typography.headline())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                IconTapButton(
                    systemName: DesignSystem.Icon.check,
                    tint: DesignSystem.Colors.accent,
                    accessibilityLabel: "Подтвердить название"
                ) {
                    confirmRenameGroup(group)
                }
                .disabled(!TaskInputValidation.canSaveGroupName(editingGroupName))

                IconTapButton(
                    systemName: DesignSystem.Icon.cancel,
                    tint: DesignSystem.Colors.textSecondary,
                    accessibilityLabel: "Отменить редактирование"
                ) {
                    cancelRenameGroup()
                }
            }
        } else {
            HStack(spacing: DesignSystem.Space.x1) {
                Image(systemName: DesignSystem.Icon.folder)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text(group.name)
                    .font(DesignSystem.Typography.headline())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(DesignSystem.Typography.data(12))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                Spacer(minLength: DesignSystem.Space.x2)
                IconTapButton(
                    systemName: DesignSystem.Icon.pencil,
                    tint: DesignSystem.Colors.accent,
                    accessibilityLabel: "Редактировать название группы"
                ) {
                    beginRenameGroup(group)
                }
                IconTapButton(
                    systemName: DesignSystem.Icon.trash,
                    role: .destructive,
                    accessibilityLabel: "Удалить группу"
                ) {
                    groupPendingDeletion = group
                    showingDeleteGroupConfirm = true
                }
            }
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

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            TaskRowView(task: task) {
                onToggle(task)
            }

            Image(systemName: DesignSystem.Icon.drag)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: DesignSystem.Space.x6, height: DesignSystem.Space.x8)
                .contentShape(Rectangle())
                .accessibilityLabel("Перетащить задачу")
                .draggable(task.uuid.uuidString)
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x1)
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
