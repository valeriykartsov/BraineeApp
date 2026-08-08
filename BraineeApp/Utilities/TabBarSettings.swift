//
//  TabBarSettings.swift
//  BraineeApp
//
//  Какие вкладки показывать. Задачи и Профиль — всегда; остальное по тумблерам.

import Foundation

struct TabBarSettings: Codable, Equatable {
    var showCalendar: Bool
    var showMatrix: Bool
    var showHabits: Bool

    static let `default` = TabBarSettings(
        showCalendar: true,
        showMatrix: false,
        showHabits: false
    )

    static let showCalendarKey = "tabBarShowCalendar"
    static let showMatrixKey = "tabBarShowMatrix"
    static let showHabitsKey = "tabBarShowHabits"
    static let storageKey = "tabBarSettings"

    enum CodingKeys: String, CodingKey {
        case showCalendar, showMatrix, showHabits
    }

    init(showCalendar: Bool, showMatrix: Bool, showHabits: Bool) {
        self.showCalendar = showCalendar
        self.showMatrix = showMatrix
        self.showHabits = showHabits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Календарь раньше был всегда включён — без ключа оставляем true.
        showCalendar = try container.decodeIfPresent(Bool.self, forKey: .showCalendar) ?? true
        showMatrix = try container.decodeIfPresent(Bool.self, forKey: .showMatrix) ?? false
        showHabits = try container.decodeIfPresent(Bool.self, forKey: .showHabits) ?? false
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
        if defaults.object(forKey: showMatrixKey) != nil {
            settings.showMatrix = defaults.bool(forKey: showMatrixKey)
        }
        if defaults.object(forKey: showHabitsKey) != nil {
            settings.showHabits = defaults.bool(forKey: showHabitsKey)
        }
        return settings
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(showCalendar, forKey: Self.showCalendarKey)
        defaults.set(showMatrix, forKey: Self.showMatrixKey)
        defaults.set(showHabits, forKey: Self.showHabitsKey)
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
