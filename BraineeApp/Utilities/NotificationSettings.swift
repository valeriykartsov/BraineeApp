//
//  NotificationSettings.swift
//  BraineeApp
//
//  Пользовательские настройки локальных уведомлений (UserDefaults).

import Foundation

struct NotificationSettings: Codable, Equatable {
    /// Мастер-свитчер «Разрешить уведомления».
    var isEnabled: Bool
    /// Напоминания о незакрытых задачах.
    var tasksEnabled: Bool
    /// Ежедневное напоминание о привычках.
    var habitsEnabled: Bool
    /// Час напоминания о привычках (0…23).
    var habitsHour: Int
    /// Минута напоминания о привычках (0…59).
    var habitsMinute: Int
    /// Напоминание в день дедлайна (приближение).
    var deadlineApproachingEnabled: Bool
    /// Напоминание о просроченном дедлайне.
    var deadlineOverdueEnabled: Bool

    static let storageKey = "notificationSettings"
    static let didRequestPermissionKey = "notificationDidRequestPermission"

    static let `default` = NotificationSettings(
        isEnabled: false,
        tasksEnabled: true,
        habitsEnabled: true,
        habitsHour: 9,
        habitsMinute: 0,
        deadlineApproachingEnabled: true,
        deadlineOverdueEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case isEnabled, tasksEnabled, habitsEnabled
        case habitsHour, habitsMinute
        case deadlineApproachingEnabled, deadlineOverdueEnabled
    }

    init(
        isEnabled: Bool,
        tasksEnabled: Bool,
        habitsEnabled: Bool,
        habitsHour: Int,
        habitsMinute: Int,
        deadlineApproachingEnabled: Bool,
        deadlineOverdueEnabled: Bool
    ) {
        self.isEnabled = isEnabled
        self.tasksEnabled = tasksEnabled
        self.habitsEnabled = habitsEnabled
        self.habitsHour = Self.clampedHour(habitsHour)
        self.habitsMinute = Self.clampedMinute(habitsMinute)
        self.deadlineApproachingEnabled = deadlineApproachingEnabled
        self.deadlineOverdueEnabled = deadlineOverdueEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        tasksEnabled = try container.decodeIfPresent(Bool.self, forKey: .tasksEnabled) ?? true
        habitsEnabled = try container.decodeIfPresent(Bool.self, forKey: .habitsEnabled) ?? true
        habitsHour = Self.clampedHour(try container.decodeIfPresent(Int.self, forKey: .habitsHour) ?? 9)
        habitsMinute = Self.clampedMinute(try container.decodeIfPresent(Int.self, forKey: .habitsMinute) ?? 0)
        deadlineApproachingEnabled = try container.decodeIfPresent(Bool.self, forKey: .deadlineApproachingEnabled) ?? true
        deadlineOverdueEnabled = try container.decodeIfPresent(Bool.self, forKey: .deadlineOverdueEnabled) ?? true
    }

    static func load(defaults: UserDefaults = .standard) -> NotificationSettings {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Время напоминания о привычках как Date (сегодня + час/минута).
    var habitsReminderDate: Date {
        get {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = habitsHour
            components.minute = habitsMinute
            return Calendar.current.date(from: components) ?? .now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            habitsHour = Self.clampedHour(components.hour ?? 9)
            habitsMinute = Self.clampedMinute(components.minute ?? 0)
        }
    }

    private static func clampedHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampedMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }
}
