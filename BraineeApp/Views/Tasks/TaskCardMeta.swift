//
//  TaskCardMeta.swift
//  BraineeApp
//
//  Метки карточки задачи (п. 37): срок, статус, приоритет, теги (до 3), подзадачи — в этом порядке.
//  На экране идут одним потоком: не поместившаяся метка переносится на следующую строку.
//  Отдельно от View, чтобы состав и порядок проверялись тестами.

import Foundation

struct TaskCardMeta: Equatable {
    enum Chip: Equatable {
        case deadline(String, overdue: Bool)
        case status(TaskStatus)
        case priority(TaskPriority)
        case tag(String)
        case subtasks(String)
    }

    static let maxTags = 3

    var chips: [Chip]

    init(task: TaskItem, settings: TaskListDisplaySettings, overdue: Bool) {
        var chips: [Chip] = []
        if settings.showDeadline, let text = task.deadlineDisplayText {
            chips.append(.deadline(text, overdue: overdue))
        }
        if settings.showStatus {
            chips.append(.status(task.status))
        }
        if settings.showPriority {
            chips.append(.priority(task.priority))
        }
        if settings.showTags {
            chips += task.tags.prefix(Self.maxTags).map { .tag($0.name) }
        }
        // Счётчик подзадач (D-41): только если они есть; всегда последним.
        if settings.showSubtasks, let progress = task.subtaskProgressText {
            chips.append(.subtasks("☑ \(progress)"))
        }
        self.chips = chips
    }
}
