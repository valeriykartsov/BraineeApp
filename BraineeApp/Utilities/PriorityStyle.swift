//
//  PriorityStyle.swift
//  BraineeApp
//
//  Фиксированные цвета приоритета (не зависят от выбранного акцента темы).

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
