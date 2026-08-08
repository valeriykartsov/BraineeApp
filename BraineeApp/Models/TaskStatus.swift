//
//  TaskStatus.swift
//  BraineeApp
//
//  Статус задачи для списка и канбана: Новая / В работе / Готово.

import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case new
    case inProgress
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: "Новая"
        case .inProgress: "В работе"
        case .done: "Готово"
        }
    }

    /// Синхронизация с чекбоксом: выполнена ↔ Готово, иначе Новая.
    static func fromCompletion(_ isCompleted: Bool) -> TaskStatus {
        isCompleted ? .done : .new
    }
}

enum KanbanSortMode: String, CaseIterable, Identifiable {
    case priority
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .priority: "Приоритет"
        case .title: "Название"
        }
    }
}
