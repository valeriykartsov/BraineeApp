//
//  NotificationActionHandler.swift
//  BraineeApp
//
//  Нажатие кнопки уведомления о задаче (D-46): приложение не открывается, задача меняется
//  только через `TaskService` — тем же путём, что и с экрана (сохранение, виджет, Календарь, наклейка).

import Foundation
import SwiftData

@MainActor
enum NotificationActionHandler {
    enum Outcome: Equatable {
        case completed
        case alreadyCompleted
        case postponed
        case snoozed(until: Date)
        /// Задачи нет или она в корзине — ничего не делаем (D-46 п. 8).
        case taskUnavailable
    }

    @discardableResult
    static func perform(
        _ action: TaskNotificationActions.Action,
        taskUUID: UUID,
        notificationTitle: String,
        service: TaskService,
        snoozes: NotificationSnoozesFile,
        calendar: Calendar = .current
    ) -> Outcome {
        let wanted = taskUUID
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == wanted })
        guard let task = try? service.context.fetch(descriptor).first, !task.isSoftDeleted else {
            return .taskUnavailable
        }

        switch action {
        case .complete:
            guard !task.isCompleted else { return .alreadyCompleted }
            service.toggleCompletion(task, fromNotification: true)
            return .completed
        case .tomorrow:
            service.postponeToTomorrow(task, calendar: calendar, fromNotification: true)
            return .postponed
        case .snooze:
            // Данные задачи не меняются: только повтор того же уведомления через час (D-46 п. 5).
            let fireDate = service.now().addingTimeInterval(NotificationSnoozes.delay)
            let snooze = NotificationSnooze(taskUUID: task.uuid, fireDate: fireDate, title: notificationTitle)
            snoozes.save(NotificationSnoozes.adding(snooze, to: snoozes.load()))
            service.log.add(.task, "Повтор через час" + TaskService.fromNotificationNote, subject: task.title)
            return .snoozed(until: fireDate)
        }
    }
}
