//
//  AccentPalette.swift
//  BraineeApp
//
//  Выбор акцентного цвета приложения (хранится в UserDefaults и profile.json).

import SwiftUI

enum AccentPalette: String, CaseIterable, Identifiable {
    case orange
    case acidGreen
    case gray
    case lightBlue
    case blue
    case red
    case yellow
    case darkGreen
    case aquamarine

    var id: String { rawValue }

    static let storageKey = "accentPalette"
    /// Маркер: приложение уже запускалось на этом устройстве (после удаления UserDefaults пустой).
    static let hasLaunchedStorageKey = "braineeHasLaunched"

    var title: String {
        switch self {
        case .orange: "Оранжевый"
        case .acidGreen: "Кислотно-зелёный"
        case .gray: "Серый"
        case .lightBlue: "Голубой"
        case .blue: "Синий"
        case .red: "Красный"
        case .yellow: "Жёлтый"
        case .darkGreen: "Тёмно-зелёный"
        case .aquamarine: "Аквамариновый"
        }
    }

    var color: Color {
        switch self {
        case .orange: Color(hex: 0xFF6B00)
        /// Мягкий зелёный — читается на светлой теме без «кислотной» ряби.
        case .acidGreen: Color(hex: 0x34C759)
        case .gray: Color(hex: 0x8E8E93)
        case .lightBlue: Color(hex: 0x64D2FF)
        case .blue: Color(hex: 0x007AFF)
        case .red: Color(hex: 0xFF3B30)
        case .yellow: Color(hex: 0xFFD60A)
        case .darkGreen: Color(hex: 0x1B5E20)
        case .aquamarine: Color(hex: 0x00C2A8)
        }
    }

    static func resolved(from rawValue: String?) -> AccentPalette {
        guard let rawValue, let value = AccentPalette(rawValue: rawValue) else { return .orange }
        return value
    }

    static var current: AccentPalette {
        resolved(from: UserDefaults.standard.string(forKey: storageKey))
    }

    /// Имя alternate icon в Info.plist / Assets; `nil` — основная AppIcon (оранжевый).
    var alternateIconName: String? {
        switch self {
        case .orange: nil
        /// Отдельное имя без camelCase — надёжнее для Springboard, чем AppIcon-acidGreen.
        case .acidGreen: "AppIcon-green"
        case .gray: "AppIcon-gray"
        case .lightBlue: "AppIcon-lightBlue"
        case .blue: "AppIcon-blue"
        case .red: "AppIcon-red"
        case .yellow: "AppIcon-yellow"
        case .darkGreen: "AppIcon-darkGreen"
        case .aquamarine: "AppIcon-aquamarine"
        }
    }
}
