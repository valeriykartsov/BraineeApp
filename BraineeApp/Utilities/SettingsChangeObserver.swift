//
//  SettingsChangeObserver.swift
//  BraineeApp
//
//  Настройки и тема живут в UserDefaults и меняются прямо на экранах (@AppStorage).
//  Один наблюдатель за списком ключей пишет их изменения в журнал сессии (п. 16) —
//  без правок каждого экрана. Служебные ключи (время синхронизации, флаги запуска) не отслеживаются.

import Foundation

@MainActor
final class SettingsChangeObserver {
    struct Setting {
        let key: String
        let title: String
        /// Строки изменений по старому и новому значению (nil — ключа нет, действует значение по умолчанию).
        let changes: (_ old: Any?, _ new: Any?) -> [String]
    }

    static let shared = SettingsChangeObserver()

    private let defaults: UserDefaults
    private let log: SessionLog
    private let settings: [Setting]
    /// Отпечатки значений для сравнения и сами значения — для подробных строк (блоки JSON).
    private var baseline: [String: String] = [:]
    private var oldValues: [String: Any] = [:]
    private var token: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, log: SessionLog = .shared, settings: [Setting] = Setting.all) {
        self.defaults = defaults
        self.log = log
        self.settings = settings
    }

    /// Запоминает текущие значения и начинает следить. Повторный вызов ничего не делает.
    func start() {
        guard token == nil else { return }
        baseline = snapshot()
        token = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.check()
            }
        }
    }

    /// Сравнивает с запомненным и пишет в журнал только реально изменившиеся настройки.
    func check() {
        for setting in settings {
            let new = defaults.object(forKey: setting.key)
            let newStamp = Self.stamp(new)
            guard newStamp != baseline[setting.key] else { continue }
            let changes = setting.changes(oldValues[setting.key], new)
            baseline[setting.key] = newStamp
            oldValues[setting.key] = new
            guard !changes.isEmpty else { continue }
            log.add(.settings, "Настройка изменена", subject: setting.title, changes: changes)
        }
    }

    // MARK: - Снимок значений

    private func snapshot() -> [String: String] {
        var result: [String: String] = [:]
        for setting in settings {
            let value = defaults.object(forKey: setting.key)
            result[setting.key] = Self.stamp(value)
            oldValues[setting.key] = value
        }
        return result
    }

    /// Строковый отпечаток значения для сравнения; nil — ключа нет.
    private static func stamp(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let data = value as? Data { return data.base64EncodedString() }
        return "\(value)"
    }
}

// MARK: - Отслеживаемые настройки

extension SettingsChangeObserver.Setting {
    static let all: [Self] = [
        option("appTheme", "Тема") { AppTheme.resolved(from: $0 as? String ?? "").title },
        option(AccentPalette.storageKey, "Акцент") { AccentPalette.resolved(from: $0 as? String).title },
        flag(TabBarSettings.showCalendarKey, "Вкладка «Календарь»", default: true),
        flag(TabBarSettings.showLLMKey, "Вкладка «LLM»", default: false),
        flag(TabBarSettings.showHabitsKey, "Вкладка «Привычки»", default: false),
        flag(OrientationLockSettings.lockPortraitKey, "Только портретная ориентация", default: false),
        flag(CalendarExport.enabledKey, "Экспорт в Календарь", default: false),
        flag(CalendarMeetings.enabledKey, "Встречи из Календаря", default: false),
        option(LLMSettings.modelKey, "Модель LLM") { ($0 as? String) ?? LLMSettings.defaultModel },
        // Наклейка на иконке входит в блок уведомлений; её отдельный ключ — копия для таб-бара
        // и не отслеживается, иначе одно изменение попало бы в журнал дважды.
        Self(key: NotificationSettings.storageKey, title: "Уведомления") { old, new in
            notificationChanges(decode(old) ?? .default, decode(new) ?? .default)
        },
        Self(key: TaskListDisplaySettings.storageKey, title: "Вид списка задач") { old, new in
            displayChanges(decode(old) ?? .default, decode(new) ?? .default)
        },
        // Без своего ключа «Календарь» берёт поля «Задач» (`loadCalendar`) — с ними и сравниваем первое изменение.
        Self(key: TaskListDisplaySettings.calendarStorageKey, title: "Вид «Календаря»") { old, new in
            var inherited = TaskListDisplaySettings.load()
            inherited.showCompleted = true
            return displayChanges(decode(old) ?? inherited, decode(new) ?? inherited)
        }
    ]

    private static func option(_ key: String, _ title: String, describe: @escaping (Any?) -> String) -> Self {
        Self(key: key, title: title) { old, new in
            [SessionLogDiff.line(nil, describe(old), describe(new))].compactMap { $0 }
        }
    }

    private static func flag(_ key: String, _ title: String, default defaultValue: Bool) -> Self {
        option(key, title) { SessionLogDiff.onOff(($0 as? Bool) ?? defaultValue) }
    }

    private static func decode<T: Decodable>(_ value: Any?) -> T? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func notificationChanges(_ old: NotificationSettings, _ new: NotificationSettings) -> [String] {
        typealias D = SessionLogDiff
        return [
            D.line("Уведомления", D.onOff(old.isEnabled), D.onOff(new.isEnabled)),
            D.line("Напоминание о задачах", D.onOff(old.tasksEnabled), D.onOff(new.tasksEnabled)),
            D.line(
                "Время напоминания о задачах",
                D.time(hour: old.tasksHour, minute: old.tasksMinute),
                D.time(hour: new.tasksHour, minute: new.tasksMinute)
            ),
            D.line("Напоминание о привычках", D.onOff(old.habitsEnabled), D.onOff(new.habitsEnabled)),
            D.line(
                "Время напоминания о привычках",
                D.time(hour: old.habitsHour, minute: old.habitsMinute),
                D.time(hour: new.habitsHour, minute: new.habitsMinute)
            ),
            D.line("В день дедлайна", D.onOff(old.deadlineApproachingEnabled), D.onOff(new.deadlineApproachingEnabled)),
            D.line("О просрочке", D.onOff(old.deadlineOverdueEnabled), D.onOff(new.deadlineOverdueEnabled)),
            D.line("Наклейка на иконке", old.iconBadgeMode.title, new.iconBadgeMode.title)
        ].compactMap { $0 }
    }

    static func displayChanges(_ old: TaskListDisplaySettings, _ new: TaskListDisplaySettings) -> [String] {
        typealias D = SessionLogDiff
        return [
            D.line("Описание", D.onOff(old.showDetails), D.onOff(new.showDetails)),
            D.line("Срок", D.onOff(old.showDeadline), D.onOff(new.showDeadline)),
            D.line("Приоритет", D.onOff(old.showPriority), D.onOff(new.showPriority)),
            D.line("Статус", D.onOff(old.showStatus), D.onOff(new.showStatus)),
            D.line("Теги", D.onOff(old.showTags), D.onOff(new.showTags)),
            D.line("Подзадачи", D.onOff(old.showSubtasks), D.onOff(new.showSubtasks)),
            D.line("Выполненные", D.onOff(old.showCompleted), D.onOff(new.showCompleted))
        ].compactMap { $0 }
    }
}
