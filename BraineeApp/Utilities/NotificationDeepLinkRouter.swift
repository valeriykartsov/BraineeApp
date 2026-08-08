//
//  NotificationDeepLinkRouter.swift
//  BraineeApp
//
//  Маршрутизация тапа по локальному пушу → открытие карточки задачи.

import Foundation
import Combine

/// Хранит UUID задачи из уведомления, пока UI готов показать форму.
@MainActor
final class NotificationDeepLinkRouter: ObservableObject {
    static let shared = NotificationDeepLinkRouter()

    /// Ожидающая открытия задача (после тапа по пушу).
    @Published var pendingTaskUUID: UUID?

    private init() {}

    func openTask(uuid: UUID) {
        pendingTaskUUID = uuid
    }

    func clearPendingTask() {
        pendingTaskUUID = nil
    }
}
