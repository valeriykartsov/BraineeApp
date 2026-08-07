//
//  TaskPriority.swift
//  BraineeApp
//
//  Уровни приоритета задачи от низкого до наивысшего.

import Foundation

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case highest = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: "Низкий"
        case .medium: "Средний"
        case .high: "Высокий"
        case .highest: "Наивысший"
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
