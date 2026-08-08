//
//  TaskReminderOffset.swift
//  BraineeApp
//
//  Пресеты напоминаний как в нативном Calendar (до 3 на задачу).

import Foundation

/// Смещение пуша относительно дедлайна (как «Уведомление» в Календаре).
enum TaskReminderOffset: String, Codable, CaseIterable, Identifiable, Comparable {
    case atEvent
    case minutes5
    case minutes10
    case minutes15
    case minutes30
    case hours1
    case hours2
    case days1
    case days2
    case week1

    var id: String { rawValue }

    static let maxCount = 3

    /// Порядок как в меню Календаря (от ближайшего к дальнему).
    private var sortIndex: Int {
        switch self {
        case .atEvent: 0
        case .minutes5: 1
        case .minutes10: 2
        case .minutes15: 3
        case .minutes30: 4
        case .hours1: 5
        case .hours2: 6
        case .days1: 7
        case .days2: 8
        case .week1: 9
        }
    }

    static func < (lhs: TaskReminderOffset, rhs: TaskReminderOffset) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    var title: String {
        switch self {
        case .atEvent: "В момент события"
        case .minutes5: "За 5 минут"
        case .minutes10: "За 10 минут"
        case .minutes15: "За 15 минут"
        case .minutes30: "За 30 минут"
        case .hours1: "За 1 час"
        case .hours2: "За 2 часа"
        case .days1: "За 1 день"
        case .days2: "За 2 дня"
        case .week1: "За неделю"
        }
    }

    /// Минуты до якоря дедлайна (0 = в момент).
    var minutesBefore: Int {
        switch self {
        case .atEvent: 0
        case .minutes5: 5
        case .minutes10: 10
        case .minutes15: 15
        case .minutes30: 30
        case .hours1: 60
        case .hours2: 120
        case .days1: 24 * 60
        case .days2: 2 * 24 * 60
        case .week1: 7 * 24 * 60
        }
    }

    /// Нормализация списка из JSON: валидные, без дублей, не больше maxCount.
    static func normalizedList(_ raw: [String]) -> [TaskReminderOffset] {
        var result: [TaskReminderOffset] = []
        for item in raw {
            guard let offset = TaskReminderOffset(rawValue: item) else { continue }
            if !result.contains(offset) {
                result.append(offset)
            }
            if result.count >= maxCount { break }
        }
        return result
    }

    static func encodeList(_ offsets: [TaskReminderOffset]) -> [String] {
        normalizedList(offsets.map(\.rawValue)).map(\.rawValue)
    }

    /// Миграция со старого формата value + unit (1…30 мин/ч/дн).
    static func migrated(fromValue value: Int, unitRaw: String) -> TaskReminderOffset? {
        let amount = min(max(value, 1), 30)
        switch unitRaw {
        case "minutes":
            switch amount {
            case ...5: return .minutes5
            case ...10: return .minutes10
            case ...15: return .minutes15
            default: return .minutes30
            }
        case "hours":
            return amount <= 1 ? .hours1 : .hours2
        case "days":
            switch amount {
            case 1: return .days1
            case 2...6: return .days2
            default: return .week1
            }
        default:
            return .hours1
        }
    }

    /// Момент пуша: якорь дедлайна минус смещение.
    func fireDate(
        deadline: Date,
        hasDeadlineTime: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        let anchor: Date
        if hasDeadlineTime {
            anchor = deadline
        } else {
            // Без времени — как «весь день»: якорь 09:00 дня дедлайна.
            var components = calendar.dateComponents([.year, .month, .day], from: deadline)
            components.hour = 9
            components.minute = 0
            anchor = calendar.date(from: components) ?? deadline
        }

        guard let fire = calendar.date(byAdding: .minute, value: -minutesBefore, to: anchor),
              fire > now else {
            return nil
        }
        return fire
    }
}
