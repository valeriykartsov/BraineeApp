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
                            groups: groups,
                            displaySettings: displaySettings,
                            sortMode: kanbanSort,
                            collapsedGroupIDs: $collapsedGroupIDs,
                            onToggle: toggleTask,
                            onEdit: { editingTask = $0 },
                            onDelete: deleteTask,
                            onStatusChange: setStatus
                        )
                    }
                }
            }
            // Корень вкладки внутри NavigationStack: без своего фона стек непрозрачный и закрывает картинку (D-48).
            .appScreenBackground()
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
                TaskListDisplaySettingsView(
                    settings: $displaySettings,
                    showsCompletedToggle: viewMode == .list,
                    showsKanbanFoldersToggle: viewMode == .kanban
                )
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

                // В канбане — только при досках по папкам: сворачивание общее со списком (п. 44).
                if viewMode == .list || displaySettings.kanbanByFolder {
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
        // Группа только со скрытыми выполненными в списке пуста — сворачивать нечего (п. 43);
        // канбан выполненные не скрывает.
        let visible = viewMode == .list ? displaySettings.listed(Array(tasks)) : Array(tasks)
        return GroupCollapseLogic.collapsibleIDs(groups: Array(groups), tasks: visible)
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

    private var taskService: TaskService {
        TaskService(context: modelContext)
    }

    private func addTask(_ formData: TaskFormData) {
        taskService.create(from: formData)
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        taskService.update(task, from: formData)
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            taskService.toggleCompletion(task)
        }
        if task.isCompleted {
            HapticFeedback.success()
        }
    }

    private func setStatus(_ task: TaskItem, _ status: TaskStatus) {
        withAnimation {
            taskService.setStatus(task, status)
        }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            taskService.softDelete(task)
        }
    }

    private var groupService: GroupService {
        GroupService(context: modelContext)
    }

    private func deleteGroup(_ group: TaskGroup) {
        withAnimation {
            groupService.delete(group)
        }
    }

    private func createGroup() {
        guard groupService.create(name: newGroupName) != nil else { return }
        newGroupName = ""
    }
}

#Preview {
    TaskSectionView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self], inMemory: true)
}
