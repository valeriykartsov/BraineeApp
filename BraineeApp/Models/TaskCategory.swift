//
//  TaskCategory.swift
//  BraineeApp
//
//  Три раздела приложения: Карьера, Спорт, Ментальное.

import Foundation

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case career
    case sport
    case mental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .career: "Карьера"
        case .sport: "Спорт"
        case .mental: "Ментальное"
        }
    }

    var systemImage: String {
        switch self {
        case .career: "briefcase"
        case .sport: "figure.run"
        case .mental: "brain.head.profile"
        }
    }
}
