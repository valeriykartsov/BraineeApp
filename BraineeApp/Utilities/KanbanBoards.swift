//
//  KanbanBoards.swift
//  BraineeApp
//
//  Канбан «Разбить по папкам» (п. 44): какие доски показывать и в каком порядке,
//  и порядок карточек в колонке (`KanbanSortMode`, общий для одной доски и для досок по папкам).

import Foundation

/// Доска канбана: задачи одной папки или «Входящих».
struct KanbanBoard: Identifiable {
    /// uuid папки; nil — «Входящие».
    let groupID: UUID?
    let title: String
    let tasks: [TaskItem]

    static let inboxTitle = "Входящие"

    /// У «Входящих» отдельный id: не совпадёт с uuid папки.
    var id: String { groupID?.uuidString ?? "\u{0}inbox" }
    var isInbox: Bool { groupID == nil }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }

    func contains(_ task: TaskItem) -> Bool {
        tasks.contains { $0.uuid == task.uuid }
    }
}

enum KanbanBoards {
    /// Доски только у папок с задачами, по порядку папок; «Входящие» — последней, если в них есть задачи.
    static func make(groups: [TaskGroup], tasks: [TaskItem]) -> [KanbanBoard] {
        var byGroup: [UUID: [TaskItem]] = [:]
        var inbox: [TaskItem] = []
        for task in tasks {
            if let id = task.group?.uuid {
                byGroup[id, default: []].append(task)
            } else {
                inbox.append(task)
            }
        }

        var boards = groups
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { group -> KanbanBoard? in
                guard let items = byGroup[group.uuid], !items.isEmpty else { return nil }
                return KanbanBoard(groupID: group.uuid, title: group.name, tasks: items)
            }
        if !inbox.isEmpty {
            boards.append(KanbanBoard(groupID: nil, title: KanbanBoard.inboxTitle, tasks: inbox))
        }
        return boards
    }
}

extension KanbanSortMode {
    /// Порядок карточек в колонке: по приоритету (затем по названию) или по названию.
    func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        switch self {
        case .priority:
            return tasks.sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .title:
            return tasks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
}
