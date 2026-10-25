//
//  AppDelegate.swift
//  BraineeApp
//
//  UIKit-адаптер: ориентация, показ локальных уведомлений на переднем плане
//  и кнопки уведомления о задаче — в фоне, без открытия приложения (D-46).

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        TaskNotificationActions.register()
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

    // Тап по пушу → открыть карточку задачи; кнопка → действие в фоне.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        guard let uuid = AppNotifications.taskUUID(
            fromUserInfo: request.content.userInfo,
            identifier: request.identifier
        ) else {
            completionHandler()
            return
        }

        guard let action = TaskNotificationActions.Action(rawValue: response.actionIdentifier) else {
            Task { @MainActor in
                NotificationDeepLinkRouter.shared.openTask(uuid: uuid)
            }
            completionHandler()
            return
        }

        let title = request.content.title
        Task { @MainActor in
            await Self.perform(action, taskUUID: uuid, notificationTitle: title)
            completionHandler()
        }
    }

    /// iOS считает действие законченным после `completionHandler`, поэтому пересборку уведомлений
    /// ждём здесь: иначе могло бы сработать уже ненужное «просрочено» (D-46 п. 2).
    @MainActor
    private static func perform(
        _ action: TaskNotificationActions.Action,
        taskUUID: UUID,
        notificationTitle: String
    ) async {
        guard case .success(let container) = SharedModelContainer.result else { return }
        let context = container.mainContext
        // Без асинхронной пересборки внутри didChange — её ждём ниже сами.
        let service = TaskService(context: context) { AppSideEffects.didChange(in: $0, refreshNotifications: false) }
        NotificationActionHandler.perform(
            action,
            taskUUID: taskUUID,
            notificationTitle: notificationTitle,
            service: service,
            snoozes: .standard()
        )
        CalendarExport.syncIfEnabled(tasks: context.fetchActiveTasks())
        await AppNotifications.refresh(from: context)
    }
}
