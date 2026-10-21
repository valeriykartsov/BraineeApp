//
//  NotificationDeepLinkRouter.swift
//  BraineeApp
//
//  Маршрутизация тапа по локальному пушу → открытие карточки задачи;
//  виджет экрана блокировки → вкладка «Календарь» на сегодняшнем дне.

import Foundation
import Combine

/// Хранит UUID задачи из уведомления, пока UI готов показать форму.
@MainActor
final class NotificationDeepLinkRouter: ObservableObject {
    static let shared = NotificationDeepLinkRouter()

    /// Ожидающая открытия задача (после тапа по пушу).
    @Published var pendingTaskUUID: UUID?

    /// Ожидает открытия вкладка «Календарь» на сегодняшнем дне (тап по виджету экрана блокировки).
    @Published var pendingCalendarToday = false

    private init() {}

    func openTask(uuid: UUID) {
        pendingTaskUUID = uuid
    }

    func clearPendingTask() {
        pendingTaskUUID = nil
    }

    func openCalendarToday() {
        pendingCalendarToday = true
    }

    func clearPendingCalendar() {
        pendingCalendarToday = false
    }
}
