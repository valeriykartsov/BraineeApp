//
//  AppDelegate.swift
//  BraineeApp
//
//  UIKit-адаптер: ориентация и показ локальных уведомлений на переднем плане.

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLockSettings.supportedOrientations
    }

    // Показываем баннер даже когда приложение открыто.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Тап по пушу → открыть карточку задачи.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        if let uuid = AppNotifications.taskUUID(
            fromUserInfo: request.content.userInfo,
            identifier: request.identifier
        ) {
            Task { @MainActor in
                NotificationDeepLinkRouter.shared.openTask(uuid: uuid)
            }
        }
        completionHandler()
    }
}
