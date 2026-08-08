//
//  TaskSectionView.swift
//  BraineeApp
//
//  Экран «Задачи»: список или канбан, создание задач и групп.

import SwiftUI
import SwiftData

/// Режим отображения: список по папкам или канбан по статусам.
enum TaskViewMode: String, CaseIterable, Identifiable {
    case list = "Список"
    case kanban = "Канбан"

    var id: String { rawValue }
}

struct TaskSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var deepLinkRouter = NotificationDeepLinkRouter.shared

    /// Активна вкладка «Задачи» — при уходе возвращаем вид «Список».
    var isActive: Bool = true

    @Query(
        filter: #Predicate<TaskItem> { !$0.isSoftDeleted },
        sort: [SortDescriptor(\TaskItem.sortOrder)]
    )
    private var tasks: [TaskItem]

    @Query(sort: [SortDescriptor(\TaskGroup.sortOrder)])
    private var groups: [TaskGroup]

    @State private var viewMode: TaskViewMode = .list
    @State private var kanbanSort: KanbanSortMode = .priority
    @State private var showingAddTask = false
    @State private var editingTask: TaskItem?
    @State private var showingCreateGroup = false
    @State private var showingDisplaySettings = false
    @State private var newGroupName = ""
    @State private var displaySettings = TaskListDisplaySettings.load()
    /// Свёрнутые группы списка (управляется и кнопкой «все»).
    @State private var collapsedGroupIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Задачи")
                    .font(DesignSystem.Typography.title(24))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.top, DesignSystem.Space.x1)
                    .padding(.bottom, DesignSystem.Space.x2)

                sectionControlsBar
                    .padding(.bottom, DesignSystem.Space.x2)

                Group {
                    switch viewMode {
                    case .list:
                        TaskOrganizedListView(
                            groups: groups,
                            tasks: tasks,
                            displaySettings: displaySettings,
                            collapsedGroupIDs: $collapsedGroupIDs,
                            onToggle: toggleTask,
                            onDelete: deleteTask,
                            onEdit: { editingTask = $0 },
                            onDeleteGroup: deleteGroup
                        )
                    case .kanban:
                        TaskKanbanBoardView(
                            tasks: tasks,
                            displaySettings: displaySettings,
                            sortMode: kanbanSort,
                            onToggle: toggleTask,
                            onEdit: { editingTask = $0 },
                            onDelete: deleteTask,
                            onStatusChange: setStatus
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .tint(DesignSystem.Colors.accent)
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView { formData in
                    addTask(formData)
                }
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(
                    task: task,
                    onSave: { formData in
                        updateTask(task, formData: formData)
                    },
                    onDelete: { taskToDelete in
                        deleteTask(taskToDelete)
                        editingTask = nil
                    }
                )
                // Стабильный id — форма не пересоздаётся при обновлениях SwiftData во время ввода.
                .id(task.uuid)
            }
            .sheet(isPresented: $showingDisplaySettings) {
                TaskListDisplaySettingsView(settings: $displaySettings)
            }
            .alert("Новая группа", isPresented: $showingCreateGroup) {
                TextField("Название группы", text: $newGroupName)
                Button("Отмена", role: .cancel) {
                    newGroupName = ""
                }
                Button("Создать") {
                    createGroup()
                }
            } message: {
                Text("Группа появится в режиме «Список».")
            }
            .onAppear {
                displaySettings = TaskListDisplaySettings.load()
                openTaskFromDeepLinkIfNeeded()
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    viewMode = .list
                    showingAddTask = false
                    editingTask = nil
                    showingCreateGroup = false
                    showingDisplaySettings = false
                } else {
                    openTaskFromDeepLinkIfNeeded()
                }
            }
            .onChange(of: deepLinkRouter.pendingTaskUUID) { _, _ in
                openTaskFromDeepLinkIfNeeded()
            }
        }
    }

    private var sectionControlsBar: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            AppSegmentedControl(
                selection: $viewMode,
                options: TaskViewMode.allCases,
                title: { $0.rawValue }
            )

            Spacer(minLength: DesignSystem.Space.x2)

            HStack(spacing: DesignSystem.Space.x1) {
                if viewMode == .kanban {
                    Menu {
                        ForEach(KanbanSortMode.allCases) { mode in
                            Button {
                                kanbanSort = mode
                            } label: {
                                if kanbanSort == mode {
                                    Label(mode.title, systemImage: "checkmark")
                                } else {
                                    Text(mode.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Сортировка канбана")
                }

                if viewMode == .list {
                    collapseAllGroupsButton
                }

                toolbarIconButton(
                    systemName: "slider.horizontal.3",
                    label: "Настройка отображения"
                ) {
                    showingDisplaySettings = true
                }

                if viewMode == .list {
                    toolbarIconButton(
                        systemName: "folder.badge.plus",
                        label: "Создать группу"
                    ) {
                        showingCreateGroup = true
                    }
                }

                toolbarIconButton(
                    systemName: "plus",
                    label: "Добавить задачу"
                ) {
                    showingAddTask = true
                }
            }
        }
        .foregroundStyle(DesignSystem.Colors.accent)
        .padding(.horizontal, DesignSystem.Space.screenInset)
    }

    private func toolbarIconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private var collapsibleGroupIDs: Set<UUID> {
        GroupCollapseLogic.collapsibleIDs(groups: Array(groups), tasks: Array(tasks))
    }

    private var nextCollapseActionIsExpand: Bool {
        GroupCollapseLogic.nextActionIsExpand(
            collapsibleIDs: collapsibleGroupIDs,
            collapsedIDs: collapsedGroupIDs
        )
    }

    private var collapseAllGroupsButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                if nextCollapseActionIsExpand {
                    collapsedGroupIDs = GroupCollapseLogic.expanding(
                        collapsibleIDs: collapsibleGroupIDs,
                        collapsedIDs: collapsedGroupIDs
                    )
                } else {
                    collapsedGroupIDs = GroupCollapseLogic.collapsing(
                        collapsibleIDs: collapsibleGroupIDs,
                        collapsedIDs: collapsedGroupIDs
                    )
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .rotationEffect(.degrees(nextCollapseActionIsExpand ? -90 : 0))
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: nextCollapseActionIsExpand)
                .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                .contentShape(Rectangle())
        }
        .disabled(collapsibleGroupIDs.isEmpty)
        .opacity(collapsibleGroupIDs.isEmpty ? 0.35 : 1)
        .accessibilityLabel(
            nextCollapseActionIsExpand ? "Развернуть все группы" : "Свернуть все группы"
        )
    }

    /// Открывает карточку задачи после тапа по пушу (когда вкладка активна и данные загружены).
    private func openTaskFromDeepLinkIfNeeded() {
        guard isActive, let uuid = deepLinkRouter.pendingTaskUUID else { return }
        guard let task = tasks.first(where: { $0.uuid == uuid }) else { return }
        showingAddTask = false
        editingTask = task
        deepLinkRouter.clearPendingTask()
    }

    private func addTask(_ formData: TaskFormData) {
        let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TaskItem(
            title: formData.title,
            deadline: formData.deadline,
            hasDeadlineTime: formData.hasDeadlineTime,
            reminderOffsets: formData.reminderOffsets,
            priority: formData.priority,
            category: .tasks,
            status: .new,
            taskDetails: formData.taskDetails,
            sortOrder: nextOrder,
            tags: formData.selectedTags
        )
        modelContext.insert(task)
        modelContext.persistToJSON()
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        task.title = formData.title
        task.deadline = formData.deadline
        task.hasDeadlineTime = formData.hasDeadlineTime
        task.reminderOffsets = formData.reminderOffsets
        task.priority = formData.priority
        task.status = formData.status
        task.category = .tasks
        task.taskDetails = formData.taskDetails
        task.tags = formData.selectedTags
        modelContext.persistToJSON()
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            task.applyCompletionToggle()
            reorderAfterToggle(task)
        }
        if task.isCompleted {
            HapticFeedback.success()
        }
        modelContext.persistToJSON()
    }

    /// Выполненная — в конец группы/«Без папки»; снятие галочки — в конец незакрытых.
    private func reorderAfterToggle(_ task: TaskItem) {
        let peers = tasks.filter { peer in
            if let groupUUID = task.group?.uuid {
                return peer.group?.uuid == groupUUID
            }
            return peer.group == nil
        }
        if task.isCompleted {
            TaskSortHelper.moveToEnd(of: peers, task: task)
        } else {
            let incompletePeers = peers.filter { !$0.isCompleted || $0.uuid == task.uuid }
            TaskSortHelper.moveToEnd(of: incompletePeers, task: task)
        }
    }

    private func setStatus(_ task: TaskItem, _ status: TaskStatus) {
        withAnimation {
            task.status = status
        }
        modelContext.persistToJSON()
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            task.isSoftDeleted = true
            task.deletedAt = .now
        }
        try? modelContext.save()
        modelContext.persistToJSON()
    }

    private func deleteGroup(_ group: TaskGroup) {
        withAnimation {
            for task in tasks where task.group?.persistentModelID == group.persistentModelID {
                task.group = nil
            }
            modelContext.delete(group)
        }
        modelContext.persistToJSON()
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (groups.map(\.sortOrder).max() ?? -1) + 1
        let group = TaskGroup(name: trimmed, category: .tasks, sortOrder: nextOrder)
        modelContext.insert(group)
        newGroupName = ""
        modelContext.persistToJSON()
    }
}

#Preview {
    TaskSectionView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self], inMemory: true)
}
