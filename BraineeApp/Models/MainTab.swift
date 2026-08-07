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

    /// Контурная иконка (неактивная вкладка).
    var systemImage: String {
        switch self {
        case .career: "briefcase"
        case .sport: "figure.run"
        case .mental: "brain.head.profile"
        case .profile: "person"
        }
    }

    /// Более «залитая» иконка для активной вкладки (как в HH).
    var selectedSystemImage: String {
        switch self {
        case .career: "briefcase.fill"
        case .sport: "figure.run"
        case .mental: "brain.head.profile"
        case .profile: "person.fill"
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
