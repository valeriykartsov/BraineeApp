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
    var showStatus: Bool
    var showTags: Bool

    static let `default` = TaskListDisplaySettings(
        showDetails: true,
        showDeadline: true,
        showPriority: true,
        showStatus: true,
        showTags: true
    )

    static let storageKey = "taskListDisplaySettings"

    enum CodingKeys: String, CodingKey {
        case showDetails, showDeadline, showPriority, showStatus, showTags
    }

    init(
        showDetails: Bool,
        showDeadline: Bool,
        showPriority: Bool,
        showStatus: Bool,
        showTags: Bool
    ) {
        self.showDetails = showDetails
        self.showDeadline = showDeadline
        self.showPriority = showPriority
        self.showStatus = showStatus
        self.showTags = showTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showDetails = try container.decodeIfPresent(Bool.self, forKey: .showDetails) ?? true
        showDeadline = try container.decodeIfPresent(Bool.self, forKey: .showDeadline) ?? true
        showPriority = try container.decodeIfPresent(Bool.self, forKey: .showPriority) ?? true
        showStatus = try container.decodeIfPresent(Bool.self, forKey: .showStatus) ?? true
        showTags = try container.decodeIfPresent(Bool.self, forKey: .showTags) ?? true
    }

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
