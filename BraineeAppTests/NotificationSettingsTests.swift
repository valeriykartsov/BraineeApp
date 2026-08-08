//
//  NotificationSettingsTests.swift
//  BraineeAppTests
//
//  Настройки уведомлений: значения по умолчанию и сохранение.

import Foundation
import Testing
@testable import BraineeApp

struct NotificationSettingsTests {

    private func makeSuite() -> UserDefaults {
        let name = "NotificationSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func поУмолчанию_мастерВыключенДеталиВключены() {
        // До разрешения пользователя мастер выключен; детальные опции готовы.
        let settings = NotificationSettings.default
        #expect(settings.isEnabled == false)
        #expect(settings.tasksEnabled == true)
        #expect(settings.habitsEnabled == true)
        #expect(settings.habitsHour == 9)
        #expect(settings.habitsMinute == 0)
        #expect(settings.deadlineApproachingEnabled == true)
        #expect(settings.deadlineOverdueEnabled == true)
    }

    @Test func saveLoad_сохраняетВсеФлагиИВремя() {
        let defaults = makeSuite()
        var settings = NotificationSettings.default
        settings.isEnabled = true
        settings.tasksEnabled = false
        settings.habitsEnabled = true
        settings.habitsHour = 21
        settings.habitsMinute = 30
        settings.deadlineApproachingEnabled = false
        settings.deadlineOverdueEnabled = true
        settings.save(defaults: defaults)

        let loaded = NotificationSettings.load(defaults: defaults)
        #expect(loaded == settings)
    }

    @Test func старыйJSONБезПолей_читаетСДефолтами() throws {
        let defaults = makeSuite()
        let partial = #"{"isEnabled":true}"#.data(using: .utf8)!
        defaults.set(partial, forKey: NotificationSettings.storageKey)

        let loaded = NotificationSettings.load(defaults: defaults)
        #expect(loaded.isEnabled == true)
        #expect(loaded.tasksEnabled == true)
        #expect(loaded.habitsHour == 9)
    }

    @Test func времяПривычек_изDatePickerОбновляетЧасИМинуту() {
        var settings = NotificationSettings.default
        var components = DateComponents()
        components.hour = 18
        components.minute = 45
        let date = Calendar.current.date(from: components)!
        settings.habitsReminderDate = date
        #expect(settings.habitsHour == 18)
        #expect(settings.habitsMinute == 45)
    }
}
