//
//  MainTab.swift
//  BraineeApp
//
//  Вкладки: Задачи → Календарь → Матрица → Привычки → Профиль (опциональные по настройкам).

import SwiftUI

enum MainTab: Int, CaseIterable, Identifiable {
    case tasks
    case calendar
    case matrix
    case habits
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .tasks: "Задачи"
        case .calendar: "Календарь"
        case .matrix: "Матрица"
        case .habits: "Привычки"
        case .profile: "Профиль"
        }
    }

    var systemImage: String {
        switch self {
        case .tasks: "checklist"
        case .calendar: DesignSystem.Icon.calendar
        case .matrix: "square.grid.2x2"
        case .habits: "flame"
        case .profile: DesignSystem.Icon.person
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .tasks: "checklist"
        case .calendar: "calendar"
        case .matrix: "square.grid.2x2.fill"
        case .habits: "flame.fill"
        case .profile: "person.fill"
        }
    }

    /// Порядок: Задачи → Календарь → Матрица → Привычки → Профиль.
    static func visibleTabs(
        showCalendar: Bool,
        showMatrix: Bool,
        showHabits: Bool
    ) -> [MainTab] {
        var tabs: [MainTab] = [.tasks]
        if showCalendar { tabs.append(.calendar) }
        if showMatrix { tabs.append(.matrix) }
        if showHabits { tabs.append(.habits) }
        tabs.append(.profile)
        return tabs
    }
}
