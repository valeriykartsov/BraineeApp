//
//  TaskListDisplaySettings.swift
//  BraineeApp
//
//  Настройки отображения полей задачи в списке.
//  Название всегда видно; остальные поля — по чекбоксам.

import Foundation

struct TaskListDisplaySettings: Codable, Equatable {
    /// Название всегда отображается (не отключается в UI).
    static let titleAlwaysVisible = true

    var showDetails: Bool
    var showDeadline: Bool
    var showPriority: Bool
    var showTags: Bool

    static let `default` = TaskListDisplaySettings(
        showDetails: true,
        showDeadline: true,
        showPriority: true,
        showTags: true
    )

    static let storageKey = "taskListDisplaySettings"

    static func load(defaults: UserDefaults = .standard) -> TaskListDisplaySettings {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(TaskListDisplaySettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
