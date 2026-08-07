//
//  AppTheme.swift
//  BraineeApp
//
//  Настройка темы оформления: системная, светлая или тёмная.

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    /// nil для системной темы — SwiftUI сам подберёт светлую/тёмную.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Безопасно читает тему из @AppStorage или JSON, даже если значение неизвестно.
    static func resolved(from rawValue: String) -> AppTheme {
        AppTheme(rawValue: rawValue) ?? .system
    }
}
