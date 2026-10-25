//
//  TaskKanbanBoardView.swift
//  BraineeApp
//
//  Канбан: три колонки по статусу и drag-and-drop между колонками.
//  Сортировка вынесена в панель управления экрана «Задачи».
//  «Разбить по папкам» (п. 44): доски папок одна под другой, у каждой свой горизонтальный ряд колонок;
//  перенос — только внутри доски (меняет статус), сворачивание — общее со списком.

import SwiftUI

struct TaskKanbanBoardView: View {
    let tasks: [TaskItem]
    var groups: [TaskGroup] = []
    var displaySettings: TaskListDisplaySettings = .default
    var sortMode: KanbanSortMode
    /// Свёрнутые папки — то же состояние, что у списка.
    @Binding var collapsedGroupIDs: Set<UUID>

    var onToggle: (TaskItem) -> Void
    var onEdit: (TaskItem) -> Void
    var onDelete: (TaskItem) -> Void
    var onStatusChange: (TaskItem, TaskStatus) -> Void

    /// Колонка под перетаскиваемой карточкой: доска + статус.
    @State private var dropTarget: DropTarget?

    private static let columnWidth: CGFloat = 260
    /// Id единственной доски (без разбиения по папкам).
    private static let singleBoardID = "\u{0}all"

    private struct DropTarget: Equatable {
        let boardID: String
        let status: TaskStatus
    }

    var body: some View {
        Group {
            if displaySettings.kanbanByFolder {
                folderBoards
            } else {
                singleBoard
            }
        }
        .padding(.bottom, DesignSystem.Space.x2)
        .appScreenBackground()
        .taskRowClock()
    }

    // MARK: - Одна доска

    private var singleBoard: some View {
        GeometryReader { geo in
            let bottomInset = DesignSystem.Space.x3
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                    ForEach(TaskStatus.allCases) { status in
                        column(
                            for: status,
                            items: tasks.filter { $0.status == status },
                            boardID: Self.singleBoardID,
                            boardTasks: tasks,
                            height: max(geo.size.height - DesignSystem.Space.x2 - bottomInset, 280)
                        )
                    }
                }
                .groupedScreenPadding()
                .padding(.top, DesignSystem.Space.x2 + 2)
                .padding(.bottom, bottomInset)
            }
        }
    }

    // MARK: - Доски по папкам

    @ViewBuilder
    private var folderBoards: some View {
        let boards = KanbanBoards.make(groups: groups, tasks: tasks)
        if boards.isEmpty {
            EmptyTasksView()
        } else {
            // Экран — вертикально, ряд колонок доски — горизонтально; у колонок нет своей прокрутки,
            // поэтому жесты не спорят, а карточка переносится долгим удержанием.
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Space.sectionGap) {
                    ForEach(boards) { board in
                        boardSection(board)
                    }
                }
                .padding(.vertical, DesignSystem.Space.x2 + 2)
            }
        }
    }

    private func boardSection(_ board: KanbanBoard) -> some View {
        let isCollapsed = board.groupID.map { collapsedGroupIDs.contains($0) } ?? false

        return VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            boardHeader(board, isCollapsed: isCollapsed)
                .groupedScreenPadding()

            if !isCollapsed {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                        ForEach(TaskStatus.allCases) { status in
                            column(
                                for: status,
                                items: board.tasks(in: status),
                                boardID: board.id,
                                boardTasks: board.tasks,
                                height: nil
                            )
                        }
                    }
                    .groupedScreenPadding()
                }
            }
        }
    }

    /// Заголовок как у папки в списке: шеврон, иконка, название, счётчик. «Входящие» не сворачиваются, как в списке.
    private func boardHeader(_ board: KanbanBoard, isCollapsed: Bool) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            if let groupID = board.groupID {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if collapsedGroupIDs.contains(groupID) {
                            collapsedGroupIDs.remove(groupID)
                        } else {
                            collapsedGroupIDs.insert(groupID)
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Space.x2) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                        boardTitle(board, systemImage: DesignSystem.Icon.folder)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(board.title), \(board.tasks.count)")
                .accessibilityHint(isCollapsed ? "Развернуть доску" : "Свернуть доску")
            } else {
                boardTitle(board, systemImage: DesignSystem.Icon.tray)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Space.x1)
    }

    private func boardTitle(_ board: KanbanBoard, systemImage: String) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
            Text(board.title)
                .font(DesignSystem.Typography.body(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            Text("\(board.tasks.count)")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Колонка

    /// `height` nil — высота по содержимому, без своей прокрутки (доски по папкам).
    private func column(
        for status: TaskStatus,
        items unsorted: [TaskItem],
        boardID: String,
        boardTasks: [TaskItem],
        height: CGFloat?
    ) -> some View {
        let items = sortMode.sorted(unsorted)
        let target = DropTarget(boardID: boardID, status: status)
        let isTargeted = dropTarget == target
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

            if height == nil {
                columnCards(items)
            } else {
                ScrollView {
                    columnCards(items)
                }
            }
        }
        .frame(width: Self.columnWidth, alignment: .top)
        .frame(height: height, alignment: .top)
        .background(shape.fill(DesignSystem.Colors.surface))
        .overlay(
            shape.strokeBorder(
                isTargeted ? DesignSystem.Colors.accent : .clear,
                lineWidth: DesignSystem.Stroke.emphasis
            )
        )
        .contentShape(shape)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: String.self) { payload, _ in
            move(payload, to: status, within: boardTasks)
        } isTargeted: { hovering in
            if hovering {
                dropTarget = target
            } else if dropTarget == target {
                dropTarget = nil
            }
        }
    }

    private func columnCards(_ items: [TaskItem]) -> some View {
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

    /// Карточка — та же, что в списке (п. 38): фон и отступы задаёт `TaskRowView`,
    /// перенос в другую колонку — всей карточкой по долгому удержанию, без ручки.
    private func kanbanCard(_ task: TaskItem) -> some View {
        TaskRowView(
            task: task,
            displaySettings: displaySettings,
            cardFill: DesignSystem.Colors.background,
            onToggle: { onToggle(task) },
            onOpen: { onEdit(task) },
            onDelete: { onDelete(task) }
        )
        .draggable(task.uuid.uuidString) {
            Text(task.title)
                .font(DesignSystem.Typography.body(15))
                .lineLimit(2)
                .padding(DesignSystem.Space.x3)
                .frame(width: 220, alignment: .leading)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        }
    }

    /// Только задачи своей доски: карточку из другой папки колонка не принимает (п. 44).
    @discardableResult
    private func move(_ payload: [String], to status: TaskStatus, within boardTasks: [TaskItem]) -> Bool {
        defer { dropTarget = nil }
        guard let raw = payload.first,
              let id = UUID(uuidString: raw),
              let task = boardTasks.first(where: { $0.uuid == id }) else {
            return false
        }
        guard task.status != status else { return false }
        HapticFeedback.success()
        onStatusChange(task, status)
        return true
    }
}
