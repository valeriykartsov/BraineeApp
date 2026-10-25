//
//  TaskListDisplaySettings.swift
//  BraineeApp
//
//  Настройки отображения полей задачи в списке.
//  Название всегда видно; остальные поля — по чекбоксам.
//  Два независимых набора: вкладка «Задачи» (`storageKey`) и вкладка «Календарь» (`calendarStorageKey`, п. 43).

import Foundation

struct TaskListDisplaySettings: Codable, Equatable {
    /// Название всегда отображается (не отключается в UI).
    static let titleAlwaysVisible = true

    var showDetails: Bool
    var showDeadline: Bool
    var showPriority: Bool
    var showStatus: Bool
    var showTags: Bool
    /// Счётчик подзадач «☑ 2/5» (D-41); в старых настройках ключа нет — включён.
    var showSubtasks: Bool
    /// Выполненные задачи в списке (п. 43); канбан, дашборд, наклейка и виджеты от него не зависят.
    var showCompleted: Bool
    /// Канбан «Разбить по папкам» — доска на каждую папку (п. 44); по умолчанию одна доска.
    var kanbanByFolder: Bool

    static let `default` = TaskListDisplaySettings(
        showDetails: true,
        showDeadline: true,
        showPriority: true,
        showStatus: true,
        showTags: true,
        showSubtasks: true
    )

    static let storageKey = "taskListDisplaySettings"
    static let calendarStorageKey = "calendarDisplaySettings"

    enum CodingKeys: String, CodingKey {
        case showDetails, showDeadline, showPriority, showStatus, showTags, showSubtasks, showCompleted, kanbanByFolder
    }

    init(
        showDetails: Bool,
        showDeadline: Bool,
        showPriority: Bool,
        showStatus: Bool,
        showTags: Bool,
        showSubtasks: Bool = true,
        showCompleted: Bool = true,
        kanbanByFolder: Bool = false
    ) {
        self.showDetails = showDetails
        self.showDeadline = showDeadline
        self.showPriority = showPriority
        self.showStatus = showStatus
        self.showTags = showTags
        self.showSubtasks = showSubtasks
        self.showCompleted = showCompleted
        self.kanbanByFolder = kanbanByFolder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showDetails = try container.decodeIfPresent(Bool.self, forKey: .showDetails) ?? true
        showDeadline = try container.decodeIfPresent(Bool.self, forKey: .showDeadline) ?? true
        showPriority = try container.decodeIfPresent(Bool.self, forKey: .showPriority) ?? true
        showStatus = try container.decodeIfPresent(Bool.self, forKey: .showStatus) ?? true
        showTags = try container.decodeIfPresent(Bool.self, forKey: .showTags) ?? true
        showSubtasks = try container.decodeIfPresent(Bool.self, forKey: .showSubtasks) ?? true
        showCompleted = try container.decodeIfPresent(Bool.self, forKey: .showCompleted) ?? true
        kanbanByFolder = try container.decodeIfPresent(Bool.self, forKey: .kanbanByFolder) ?? false
    }

    static func load(
        key: String = storageKey,
        defaults: UserDefaults = .standard
    ) -> TaskListDisplaySettings {
        decoded(key: key, defaults: defaults) ?? .default
    }

    /// Настройки «Календаря». Пока их не меняли — поля как во вкладке «Задачи»
    /// (до п. 43 «Календарь» показывал карточки с её настройками), выполненные видны.
    static func loadCalendar(defaults: UserDefaults = .standard) -> TaskListDisplaySettings {
        if let own = decoded(key: calendarStorageKey, defaults: defaults) { return own }
        var inherited = load(defaults: defaults)
        inherited.showCompleted = true
        return inherited
    }

    private static func decoded(key: String, defaults: UserDefaults) -> TaskListDisplaySettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TaskListDisplaySettings.self, from: data)
    }

    func save(key: String = storageKey, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: key)
    }

    /// Задачи, которые видны в списке: без выполненных, если они скрыты.
    func listed(_ tasks: [TaskItem]) -> [TaskItem] {
        showCompleted ? tasks : tasks.filter { !$0.isCompleted }
    }
}
