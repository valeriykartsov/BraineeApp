//
//  TaskCategory.swift
//  BraineeApp
//
//  Единый раздел задач. Старые значения career/sport/mental мигрируются в "tasks".

import Foundation

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    /// Единственный раздел после объединения вкладок.
    case tasks

    /// Значение в JSON для всех задач и групп.
    static let unifiedRaw = TaskCategory.tasks.rawValue

    var id: String { rawValue }

    var title: String { "Задачи" }
}
