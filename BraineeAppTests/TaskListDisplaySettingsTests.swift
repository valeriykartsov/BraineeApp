//
//  TaskListDisplaySettingsTests.swift
//  BraineeAppTests
//
//  Настройки отображения списка задач: дефолты и сохранение.

import Foundation
import Testing
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
            showTags: false
        )
        settings.save(defaults: defaults)

        let loaded = TaskListDisplaySettings.load(defaults: defaults)
        #expect(loaded.showDetails == false)
        #expect(loaded.showDeadline == false)
        #expect(loaded.showPriority == false)
        #expect(loaded.showTags == false)
        #expect(TaskListDisplaySettings.titleAlwaysVisible)
    }
}
