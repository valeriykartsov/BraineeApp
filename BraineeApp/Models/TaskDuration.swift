//
//  TaskDuration.swift
//  BraineeApp
//
//  Длительность задачи со временем (D-40): фиксированный список, 30 мин по умолчанию.
//  В данных 30 мин хранится как «не выбрана» (nil) — так новые и старые задачи без выбора одинаковы.

import Foundation

enum TaskDuration {
    static let defaultMinutes = 30
    /// Варианты в форме: 30 мин, 1 ч, 1,5 ч, 2 ч, 2,5 ч, 3 ч.
    static let options = [30, 60, 90, 120, 150, 180]

    /// Что сохранить в задаче: без времени длительности нет; значение по умолчанию — nil.
    static func stored(_ minutes: Int?, hasDeadlineTime: Bool) -> Int? {
        guard hasDeadlineTime, let minutes, minutes > 0, minutes != defaultMinutes else { return nil }
        return minutes
    }

    /// Длительность для показа и Календаря: nil — значение по умолчанию.
    static func effective(_ minutes: Int?) -> Int {
        guard let minutes, minutes > 0 else { return defaultMinutes }
        return minutes
    }

    /// «30 мин», «1 ч», «1,5 ч», «2,5 ч»; значение не из списка — «1 ч 15 мин».
    static func title(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(minutes) мин" }
        if rest == 0 { return "\(hours) ч" }
        if rest == 30 { return "\(hours),5 ч" }
        return "\(hours) ч \(rest) мин"
    }
}

extension TaskItem {
    /// Длительность в минутах с учётом значения по умолчанию (D-40).
    var effectiveDurationMinutes: Int {
        TaskDuration.effective(durationMinutes)
    }
}
