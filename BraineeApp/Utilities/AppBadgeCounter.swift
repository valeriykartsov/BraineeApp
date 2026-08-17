//
//  AppBadgeCounter.swift
//  BraineeApp
//
//  Подсчёт числа для наклейки на иконке и вкладке «Задачи».

import Foundation

enum AppBadgeCounter {
    static let displayCap = 99

    /// Сколько задач попадает в выбранный режим (без soft-delete и без выполненных).
    static func count(
        tasks: [TaskItem],
        mode: AppIconBadgeMode,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        switch mode {
        case .off:
            return 0
        case .overdue:
            return tasks.filter { task in
                !task.isSoftDeleted && !task.isCompleted && task.isOverdue(at: now, calendar: calendar)
            }.count
        case .todayAndOverdue:
            return tasks.filter { task in
                guard !task.isSoftDeleted, !task.isCompleted else { return false }
                if task.isOverdue(at: now, calendar: calendar) { return true }
                guard let deadline = task.deadline else { return false }
                return calendar.isDate(deadline, inSameDayAs: calendar.startOfDay(for: now))
            }.count
        }
    }

    /// Текст для UI: nil если 0, иначе число или «99+».
    static func displayText(for count: Int) -> String? {
        guard count > 0 else { return nil }
        if count > displayCap { return "\(displayCap)+" }
        return "\(count)"
    }
}
