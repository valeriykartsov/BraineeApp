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
        #expect(settings.tasksHour == 10)
        #expect(settings.tasksMinute == 0)
        #expect(settings.habitsHour == 9)
        #expect(settings.habitsMinute == 0)
        #expect(settings.deadlineApproachingEnabled == true)
        #expect(settings.deadlineOverdueEnabled == true)
        #expect(settings.iconBadgeMode == .overdue)
    }

    @Test func saveLoad_сохраняетВсеФлагиИВремя() {
        let defaults = makeSuite()
        var settings = NotificationSettings.default
        settings.isEnabled = true
        settings.tasksEnabled = false
        settings.habitsEnabled = true
        settings.tasksHour = 11
        settings.tasksMinute = 15
        settings.habitsHour = 21
        settings.habitsMinute = 30
        settings.deadlineApproachingEnabled = false
        settings.deadlineOverdueEnabled = true
        settings.iconBadgeMode = .todayAndOverdue
        settings.save(defaults: defaults)

        let loaded = NotificationSettings.load(defaults: defaults)
        #expect(loaded == settings)
        #expect(defaults.string(forKey: NotificationSettings.iconBadgeModeKey) == AppIconBadgeMode.todayAndOverdue.rawValue)
    }

    @Test func старыйJSONБезПолей_читаетСДефолтами() throws {
        let defaults = makeSuite()
        let partial = #"{"isEnabled":true}"#.data(using: .utf8)!
        defaults.set(partial, forKey: NotificationSettings.storageKey)

        let loaded = NotificationSettings.load(defaults: defaults)
        #expect(loaded.isEnabled == true)
        #expect(loaded.tasksEnabled == true)
        #expect(loaded.tasksHour == 10)
        #expect(loaded.habitsHour == 9)
        #expect(loaded.iconBadgeMode == .overdue)
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

    @Test func времяЗадач_изDatePickerОбновляетЧасИМинуту() {
        // То же для напоминания об использовании приложения (задачи).
        var settings = NotificationSettings.default
        var components = DateComponents()
        components.hour = 14
        components.minute = 5
        let date = Calendar.current.date(from: components)!
        settings.tasksReminderDate = date
        #expect(settings.tasksHour == 14)
        #expect(settings.tasksMinute == 5)
    }
}
