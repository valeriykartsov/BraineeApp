//
//  PriorityStyle.swift
//  BraineeApp
//

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
