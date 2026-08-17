//
//  AppIconBadgeMode.swift
//  BraineeApp
//
//  Режим красной наклейки на иконке и счётчика на вкладке «Задачи».

import Foundation

enum AppIconBadgeMode: String, CaseIterable, Codable, Identifiable {
    /// Не показывать число на иконке и на вкладке.
    case off
    /// Только просроченные незакрытые задачи.
    case overdue
    /// Просроченные + с дедлайном сегодня.
    case todayAndOverdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Выкл"
        case .overdue: "Просроченные"
        case .todayAndOverdue: "Сегодня и просроченные"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            "Наклейка на иконке и счётчик на вкладке «Задачи» скрыты"
        case .overdue:
            "Число незакрытых задач с прошедшим дедлайном"
        case .todayAndOverdue:
            "Просроченные и задачи на сегодня"
        }
    }

    static func resolved(from raw: String?) -> AppIconBadgeMode {
        AppIconBadgeMode(rawValue: raw ?? "") ?? .overdue
    }
}
