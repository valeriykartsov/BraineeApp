//
//  TabBarSettings.swift
//  BraineeApp
//
//  Какие вкладки показывать. Задачи и Профиль — всегда; остальное по тумблерам.
//  Вкладка «LLM» заменила «Матрицу» (NAV-1): без своей настройки берётся прежний флаг Матрицы.

import Foundation

struct TabBarSettings: Codable, Equatable {
    var showCalendar: Bool
    var showLLM: Bool
    var showHabits: Bool

    static let `default` = TabBarSettings(
        showCalendar: true,
        showLLM: false,
        showHabits: false
    )

    static let showCalendarKey = "tabBarShowCalendar"
    static let showLLMKey = "tabBarShowLLM"
    static let showHabitsKey = "tabBarShowHabits"
    static let storageKey = "tabBarSettings"
    /// Флаг вкладки «Матрица» до NAV-1. Только читается — для переноса в `showLLM`.
    static let legacyShowMatrixKey = "tabBarShowMatrix"

    enum CodingKeys: String, CodingKey {
        case showCalendar, showLLM, showHabits
        case legacyShowMatrix = "showMatrix"
    }

    init(showCalendar: Bool, showLLM: Bool, showHabits: Bool) {
        self.showCalendar = showCalendar
        self.showLLM = showLLM
        self.showHabits = showHabits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Календарь раньше был всегда включён — без ключа оставляем true.
        showCalendar = try container.decodeIfPresent(Bool.self, forKey: .showCalendar) ?? true
        showLLM = try container.decodeIfPresent(Bool.self, forKey: .showLLM)
            ?? container.decodeIfPresent(Bool.self, forKey: .legacyShowMatrix)
            ?? false
        showHabits = try container.decodeIfPresent(Bool.self, forKey: .showHabits) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showCalendar, forKey: .showCalendar)
        try container.encode(showLLM, forKey: .showLLM)
        try container.encode(showHabits, forKey: .showHabits)
    }

    static func load(defaults: UserDefaults = .standard) -> TabBarSettings {
        var settings = TabBarSettings.default
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(TabBarSettings.self, from: data) {
            settings = decoded
        }

        if defaults.object(forKey: showCalendarKey) != nil {
            settings.showCalendar = defaults.bool(forKey: showCalendarKey)
        }
        settings.showLLM = resolvedShowLLM(defaults: defaults, fallback: settings.showLLM)
        if defaults.object(forKey: showHabitsKey) != nil {
            settings.showHabits = defaults.bool(forKey: showHabitsKey)
        }
        return settings
    }

    /// Свой флаг «LLM», иначе прежний флаг «Матрицы», иначе `fallback`.
    static func resolvedShowLLM(defaults: UserDefaults = .standard, fallback: Bool = false) -> Bool {
        if defaults.object(forKey: showLLMKey) != nil {
            return defaults.bool(forKey: showLLMKey)
        }
        if defaults.object(forKey: legacyShowMatrixKey) != nil {
            return defaults.bool(forKey: legacyShowMatrixKey)
        }
        return fallback
    }

    /// Однократно переносит прежний флаг «Матрицы» в флаг «LLM», чтобы `@AppStorage` видел значение.
    static func migrateLegacyMatrixFlag(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: showLLMKey) == nil,
              defaults.object(forKey: legacyShowMatrixKey) != nil else { return }
        defaults.set(defaults.bool(forKey: legacyShowMatrixKey), forKey: showLLMKey)
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(showCalendar, forKey: Self.showCalendarKey)
        defaults.set(showLLM, forKey: Self.showLLMKey)
        defaults.set(showHabits, forKey: Self.showHabitsKey)
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
