//
//  AppBadgeSync.swift
//  BraineeApp
//
//  Синхронизация системного badge на иконке Home Screen.

import Foundation
import UserNotifications

enum AppBadgeSync {
    /// Выставляет badge иконки по режиму из настроек и списку задач.
    static func sync(
        tasks: [TaskItem],
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) async {
        let mode = NotificationSettings.load(defaults: defaults).iconBadgeMode
        let count = AppBadgeCounter.count(tasks: tasks, mode: mode)
        await apply(count: count, center: center)
    }

    static func apply(
        count: Int,
        center: UNUserNotificationCenter = .current()
    ) async {
        do {
            try await center.setBadgeCount(count)
        } catch {
            print("App badge sync error: \(error.localizedDescription)")
        }
    }
}
