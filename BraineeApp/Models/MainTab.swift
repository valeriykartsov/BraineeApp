//
//  MainTab.swift
//  BraineeApp
//
//  Описывает вкладки нижней панели: три раздела задач и профиль.

import SwiftUI

enum MainTab: Int, CaseIterable, Identifiable {
    case career
    case sport
    case mental
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .career: TaskCategory.career.title
        case .sport: TaskCategory.sport.title
        case .mental: TaskCategory.mental.title
        case .profile: "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .career: TaskCategory.career.systemImage
        case .sport: TaskCategory.sport.systemImage
        case .mental: TaskCategory.mental.systemImage
        case .profile: "person.circle.fill"
        }
    }

    /// Раздел задач для вкладки; для профиля — nil.
    var category: TaskCategory? {
        switch self {
        case .career: .career
        case .sport: .sport
        case .mental: .mental
        case .profile: nil
        }
    }
}
