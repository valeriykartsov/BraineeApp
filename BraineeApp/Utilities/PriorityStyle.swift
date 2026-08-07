//
//  PriorityStyle.swift
//  BraineeApp
//
//  Цвета бейджей приоритета в палитре дизайн-системы (серый → оранжевый акцент).

import SwiftUI

enum PriorityStyle {
    static func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: DesignSystem.Colors.textSecondary
        case .medium: DesignSystem.Colors.textPrimary
        case .high: DesignSystem.Colors.accent
        case .highest: DesignSystem.Colors.danger
        }
    }
}
