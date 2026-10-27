//
//  TaskSubtask.swift
//  BraineeApp
//
//  Подзадача — строка текста с чекбоксом внутри задачи (SchemaV2, D-39).
//  Живёт только в приложении и бэкапе: не уходит в Календарь, LLM и виджеты.
//  Удаляется вместе с задачей при окончательном удалении; корзина подзадачи не трогает.

import Foundation
import SwiftData

@Model
final class TaskSubtask {
    /// Один uuid — одна запись (D-17).
    #Unique<TaskSubtask>([\.uuid])

    var uuid: UUID
    var title: String
    var isDone: Bool
    /// Порядок внутри задачи (по возрастанию).
    var sortOrder: Int

    var task: TaskItem?

    init(uuid: UUID = UUID(), title: String, isDone: Bool = false, sortOrder: Int = 0) {
        self.uuid = uuid
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
    }
}

/// Подзадача в форме задачи до сохранения; порядок — порядок в массиве.
struct SubtaskDraft: Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
}

/// Правила подзадач (D-41): не больше 10, текст до 50 символов, пустые отбрасываются.
enum TaskSubtaskRules {
    static let maxCount = 10
    static let titleMaxLength = 50

    /// Заменяет черновик с тем же `id`. Если его уже нет — строку удалили, пока её поле было в фокусе,
    /// и поле дописывает текст при снятии фокуса — список не меняется (раньше это роняло приложение).
    static func replacing(_ draft: SubtaskDraft, in drafts: [SubtaskDraft]) -> [SubtaskDraft] {
        guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return drafts }
        var result = drafts
        result[index] = draft
        return result
    }

    /// Что сохранится: текст обрезан по краям и по длине, пустые убраны, повторы id убраны, не больше 10.
    static func normalized(_ drafts: [SubtaskDraft]) -> [SubtaskDraft] {
        var seen = Set<UUID>()
        let cleaned: [SubtaskDraft] = drafts.compactMap { draft in
            let title = String(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(titleMaxLength))
            guard !title.isEmpty, seen.insert(draft.id).inserted else { return nil }
            return SubtaskDraft(id: draft.id, title: title, isDone: draft.isDone)
        }
        return Array(cleaned.prefix(maxCount))
    }

    static func drafts(of task: TaskItem) -> [SubtaskDraft] {
        task.sortedSubtasks.map { SubtaskDraft(id: $0.uuid, title: $0.title, isDone: $0.isDone) }
    }
}

extension TaskItem {
    /// «2/5» для счётчика в строке; nil — подзадач нет.
    var subtaskProgressText: String? {
        guard !subtasks.isEmpty else { return nil }
        return "\(subtasks.filter(\.isDone).count)/\(subtasks.count)"
    }
}
