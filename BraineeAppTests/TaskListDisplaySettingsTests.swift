//
//  TaskListDisplaySettingsTests.swift
//  BraineeAppTests
//
//  Настройки отображения списка задач: дефолты и сохранение.
//  «Показывать выполненные» и отдельный набор «Календаря» (п. 43).

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

struct TaskListDisplaySettingsTests {
    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "TaskListDisplaySettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    // По умолчанию название всегда видно, остальные поля включены.
    @Test func дефолтныеНастройки_названиеВсегдаИПоляВключены() {
        let settings = TaskListDisplaySettings.default
        #expect(TaskListDisplaySettings.titleAlwaysVisible)
        #expect(settings.showDetails)
        #expect(settings.showDeadline)
        #expect(settings.showPriority)
        #expect(settings.showStatus)
        #expect(settings.showTags)
    }

    // save/load сохраняют изменённые флаги.
    @Test func сохранениеИЗагрузка_возвращаютИзменённыеФлаги() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = TaskListDisplaySettings.default
        settings.showDetails = false
        settings.showTags = false
        settings.save(defaults: defaults)

        let loaded = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loaded.showDetails == false)
        #expect(loaded.showTags == false)
        #expect(loaded.showDeadline == true)
    }

    // Битый JSON в UserDefaults не роняет приложение — возвращаем дефолт.
    @Test func битыйJSONВUserDefaults_loadВозвращаетDefault() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not-json".utf8), forKey: TaskListDisplaySettings.storageKey)

        let loaded = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loaded == .default)
    }

    // Все опциональные поля можно выключить и снова прочитать.
    @Test func всеФлагиВыключены_saveLoadСохраняет() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = TaskListDisplaySettings(
            showDetails: false,
            showDeadline: false,
            showPriority: false,
            showStatus: false,
            showTags: false
        )
        settings.save(defaults: defaults)

        let loaded = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loaded.showDetails == false)
        #expect(loaded.showDeadline == false)
        #expect(loaded.showPriority == false)
        #expect(loaded.showStatus == false)
        #expect(loaded.showTags == false)
        #expect(TaskListDisplaySettings.titleAlwaysVisible)
    }

    // Старые настройки без ключа showCompleted читаются с включённым «Показывать выполненные».
    @Test func старыйJSONБезShowCompleted_выполненныеВидны() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let json = #"{"showDetails":false,"showDeadline":true,"showPriority":true,"showStatus":true,"showTags":true}"#
        defaults.set(Data(json.utf8), forKey: TaskListDisplaySettings.storageKey)

        let loaded = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loaded.showCompleted)
        #expect(loaded.showDetails == false)
        #expect(TaskListDisplaySettings.default.showCompleted)
    }

    // Выключенное «Показывать выполненные» убирает из списка только выполненные задачи.
    @MainActor
    @Test func выполненныеСкрыты_listedБезВыполненных() throws {
        // Контейнер держим до конца теста: модели без него обращаются к освобождённой памяти.
        let container = try TestHelpers.makeContainer()
        withExtendedLifetime(container) {
            let open = TaskItem(title: "Открытая")
            let done = TaskItem(title: "Готовая")
            container.mainContext.insert(open)
            container.mainContext.insert(done)
            done.status = .done

            var settings = TaskListDisplaySettings.default
            #expect(settings.listed([open, done]).map(\.title) == ["Открытая", "Готовая"])

            settings.showCompleted = false
            #expect(settings.listed([open, done]).map(\.title) == ["Открытая"])
        }
    }

    // Пока у «Календаря» нет своих настроек — поля как у «Задач», выполненные видны.
    @Test func календарьБезСвоихНастроек_поляКакУЗадач() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var tasksTab = TaskListDisplaySettings.default
        tasksTab.showTags = false
        tasksTab.showCompleted = false
        tasksTab.save(defaults: defaults)

        let calendar = TaskListDisplaySettings.loadCalendar(defaults: defaults)
        #expect(calendar.showTags == false)
        #expect(calendar.showCompleted)
    }

    // Свои настройки «Календаря» хранятся отдельно и не меняют вкладку «Задачи».
    @Test func настройкиКалендаря_независимыОтЗадач() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = TaskListDisplaySettings.default
        calendar.showCompleted = false
        calendar.showDetails = false
        calendar.save(key: TaskListDisplaySettings.calendarStorageKey, defaults: defaults)

        var tasksTab = TaskListDisplaySettings.default
        tasksTab.showTags = false
        tasksTab.save(defaults: defaults)

        let loadedCalendar = TaskListDisplaySettings.loadCalendar(defaults: defaults)
        let loadedTasks = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loadedCalendar.showCompleted == false)
        #expect(loadedCalendar.showDetails == false)
        #expect(loadedCalendar.showTags)
        #expect(loadedTasks.showCompleted)
        #expect(loadedTasks.showDetails)
        #expect(loadedTasks.showTags == false)
    }

    // Журнал сессии называет смену «Выполненные».
    @Test func сменаПоказаВыполненных_строкаВЖурнале() {
        var new = TaskListDisplaySettings.default
        new.showCompleted = false

        let lines = SettingsChangeObserver.Setting.displayChanges(.default, new)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("Выполненные") == true)
    }
}
