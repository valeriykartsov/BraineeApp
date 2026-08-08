//
//  AppNotifications.swift
//  BraineeApp
//
//  Запрос разрешения и планирование локальных уведомлений.

import Foundation
import SwiftData
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum AppNotifications {
    static let taskUUIDUserInfoKey = "taskUUID"

    private static let habitsIdentifier = "brainee.habits.daily"
    private static let tasksDailyIdentifier = "brainee.tasks.daily"
    static let deadlineApproachingPrefix = "brainee.deadline.approach."
    static let deadlineOverduePrefix = "brainee.deadline.overdue."

    /// Достаёт UUID задачи из userInfo пуша или из identifier (approach./overdue.).
    static func taskUUID(
        fromUserInfo userInfo: [AnyHashable: Any],
        identifier: String
    ) -> UUID? {
        if let raw = userInfo[taskUUIDUserInfoKey] as? String,
           let uuid = UUID(uuidString: raw) {
            return uuid
        }
        for prefix in [deadlineApproachingPrefix, deadlineOverduePrefix] where identifier.hasPrefix(prefix) {
            let idPart = String(identifier.dropFirst(prefix.count))
            // approach.<uuid> или approach.<uuid>.<offset>
            let uuidPart = idPart.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init) ?? idPart
            if let uuid = UUID(uuidString: uuidPart) {
                return uuid
            }
        }
        return nil
    }

    // MARK: - Permission

    /// Запрашивает системное разрешение один раз при установке/первом запуске.
    static func requestPermissionOnFirstLaunchIfNeeded(
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        guard !defaults.bool(forKey: NotificationSettings.didRequestPermissionKey) else { return }
        defaults.set(true, forKey: NotificationSettings.didRequestPermissionKey)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            guard granted else { return }
            var settings = NotificationSettings.load(defaults: defaults)
            settings.isEnabled = true
            settings.save(defaults: defaults)
        }
    }

    static func authorizationStatus(
        center: UNUserNotificationCenter = .current()
    ) async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Включает мастер-свитчер: при необходимости снова просит разрешение или открывает Настройки.
    @MainActor
    static func setMasterEnabled(
        _ enabled: Bool,
        tasks: [TaskItem],
        habits: [Habit],
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) async {
        var settings = NotificationSettings.load(defaults: defaults)
        settings.isEnabled = enabled
        settings.save(defaults: defaults)

        if enabled {
            let status = await authorizationStatus(center: center)
            switch status {
            case .notDetermined:
                let granted = await requestAuthorization(center: center)
                if !granted {
                    settings.isEnabled = false
                    settings.save(defaults: defaults)
                }
            case .denied:
                openSystemSettings()
            default:
                break
            }
        }

        await refresh(tasks: tasks, habits: habits, defaults: defaults, center: center)
    }

    static func requestAuthorization(
        center: UNUserNotificationCenter = .current()
    ) async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    static func openSystemSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }

    // MARK: - Schedule

    /// Пересобирает все локальные уведомления по текущим настройкам и данным.
    static func refresh(
        tasks: [TaskItem],
        habits: [Habit],
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current(),
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let settings = NotificationSettings.load(defaults: defaults)
        center.removeAllPendingNotificationRequests()

        guard settings.isEnabled else { return }
        let status = await authorizationStatus(center: center)
        guard status == .authorized || status == .provisional else { return }

        if settings.tasksEnabled {
            scheduleTasksReminder(tasks: tasks, center: center)
        }
        if settings.habitsEnabled, !habits.isEmpty {
            scheduleHabitsReminder(settings: settings, habits: habits, center: center)
        }
        if settings.deadlineApproachingEnabled || settings.deadlineOverdueEnabled {
            scheduleDeadlineReminders(
                settings: settings,
                tasks: tasks,
                center: center,
                now: now,
                calendar: calendar
            )
        }
    }

    static func refresh(from context: ModelContext) async {
        let tasks = context.fetchActiveTasks()
        let habits = context.fetchHabits()
        await refresh(tasks: tasks, habits: habits)
    }

    // MARK: Private builders

    private static func scheduleTasksReminder(
        tasks: [TaskItem],
        center: UNUserNotificationCenter
    ) {
        let activeCount = tasks.filter { !$0.isCompleted }.count
        guard activeCount > 0 else { return }

        var date = DateComponents()
        date.hour = 10
        date.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Задачи"
        content.body = activeCount == 1
            ? "У вас 1 незакрытая задача"
            : "У вас \(activeCount) незакрытых задач"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: tasksDailyIdentifier, content: content, trigger: trigger))
    }

    private static func scheduleHabitsReminder(
        settings: NotificationSettings,
        habits: [Habit],
        center: UNUserNotificationCenter
    ) {
        var date = DateComponents()
        date.hour = settings.habitsHour
        date.minute = settings.habitsMinute

        let content = UNMutableNotificationContent()
        content.title = "Привычки"
        content.body = habits.count == 1
            ? "Не забудьте отметить привычку «\(habits[0].title)»"
            : "Время отметить привычки (\(habits.count))"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: habitsIdentifier, content: content, trigger: trigger))
    }

    private static func scheduleDeadlineReminders(
        settings: NotificationSettings,
        tasks: [TaskItem],
        center: UNUserNotificationCenter,
        now: Date,
        calendar: Calendar
    ) {
        let today = calendar.startOfDay(for: now)

        for task in tasks where !task.isCompleted {
            guard let deadline = task.deadline else { continue }
            let deadlineDay = calendar.startOfDay(for: deadline)

            if settings.deadlineApproachingEnabled {
                let personal = task.reminderFireDates(now: now, calendar: calendar)
                if !personal.isEmpty {
                    // Пресеты из карточки задачи — до 3 пушей.
                    for item in personal {
                        let fire = calendar.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: item.date
                        )
                        addApproaching(
                            task: task,
                            fire: fire,
                            suffix: item.offset.rawValue,
                            center: center
                        )
                    }
                } else if deadlineDay >= today {
                    var fire = calendar.dateComponents([.year, .month, .day], from: deadlineDay)
                    if task.hasDeadlineTime {
                        let time = calendar.dateComponents([.hour, .minute], from: deadline)
                        if let hour = time.hour, let minute = time.minute,
                           let exact = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: deadlineDay),
                           let approach = calendar.date(byAdding: .hour, value: -1, to: exact),
                           approach > now {
                            fire = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: approach)
                        } else {
                            fire.hour = 9
                            fire.minute = 0
                        }
                    } else {
                        fire.hour = 9
                        fire.minute = 0
                    }

                    if let fireDate = calendar.date(from: fire), fireDate > now {
                        addApproaching(task: task, fire: fire, suffix: nil, center: center)
                    }
                }
            }

            if settings.deadlineOverdueEnabled {
                if deadlineDay < today {
                    var fire = calendar.dateComponents([.year, .month, .day], from: today)
                    fire.hour = 11
                    fire.minute = 0
                    if let fireDate = calendar.date(from: fire), fireDate > now {
                        addOverdue(task: task, fire: fire, center: center)
                    }
                } else if let nextMorning = calendar.date(byAdding: .day, value: 1, to: deadlineDay) {
                    var fire = calendar.dateComponents([.year, .month, .day], from: nextMorning)
                    fire.hour = 11
                    fire.minute = 0
                    if let fireDate = calendar.date(from: fire), fireDate > now {
                        addOverdue(task: task, fire: fire, center: center)
                    }
                }
            }
        }
    }

    private static func addApproaching(
        task: TaskItem,
        fire: DateComponents,
        suffix: String?,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание о задаче"
        content.body = task.title
        content.sound = .default
        content.userInfo = [taskUUIDUserInfoKey: task.uuid.uuidString]
        let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)
        let identifier: String
        if let suffix, !suffix.isEmpty {
            identifier = deadlineApproachingPrefix + task.uuid.uuidString + "." + suffix
        } else {
            identifier = deadlineApproachingPrefix + task.uuid.uuidString
        }
        center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    private static func addOverdue(
        task: TaskItem,
        fire: DateComponents,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Просроченный дедлайн"
        content.body = task.title
        content.sound = .default
        content.userInfo = [taskUUIDUserInfoKey: task.uuid.uuidString]
        let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)
        center.add(
            UNNotificationRequest(
                identifier: deadlineOverduePrefix + task.uuid.uuidString,
                content: content,
                trigger: trigger
            )
        )
    }
}

extension ModelContext {
    func fetchActiveTasks() -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isSoftDeleted }
        )
        return (try? fetch(descriptor)) ?? []
    }

    func fetchHabits() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\Habit.sortOrder)]
        )
        return (try? fetch(descriptor)) ?? []
    }
}
