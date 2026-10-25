//
//  TaskNotificationActions.swift
//  BraineeApp
//
//  Кнопки уведомления о задаче (D-46): «Выполнено», «Напомнить через час», «На завтра».
//  Только у уведомлений конкретной задачи; общие напоминания — без кнопок.
//  Ни одна кнопка не открывает приложение: действие выполняется в фоне (`NotificationActionHandler`).

import UserNotifications

enum TaskNotificationActions {
    static let categoryIdentifier = "brainee.task"

    enum Action: String, CaseIterable {
        case complete = "brainee.task.complete"
        case snooze = "brainee.task.snooze"
        case tomorrow = "brainee.task.tomorrow"

        var title: String {
            switch self {
            case .complete: "Выполнено"
            case .snooze: "Напомнить через час"
            case .tomorrow: "На завтра"
            }
        }

        /// Меняющие задачу кнопки на заблокированном телефоне сначала просят разблокировать (D-46 п. 6).
        var options: UNNotificationActionOptions {
            switch self {
            case .complete, .tomorrow: [.authenticationRequired]
            case .snooze: []
            }
        }
    }

    static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: Action.allCases.map {
                UNNotificationAction(identifier: $0.rawValue, title: $0.title, options: $0.options)
            },
            intentIdentifiers: [],
            options: []
        )
    }

    /// Регистрация при запуске; категории хранит система, повторный вызов заменяет набор.
    static func register(center: UNUserNotificationCenter = .current()) {
        center.setNotificationCategories([category])
    }
}
