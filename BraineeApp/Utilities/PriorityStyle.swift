//
//  PriorityStyle.swift
//  BraineeApp
//
//  Цвета бейджей приоритета задачи (низкий, средний, высокий, наивысший).

import SwiftUI

enum PriorityStyle {
    static func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .highest: .red
        }
    }
}
