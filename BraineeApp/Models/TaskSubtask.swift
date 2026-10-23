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
