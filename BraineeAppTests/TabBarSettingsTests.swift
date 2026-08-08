//
//  TabBarSettingsTests.swift
//  BraineeAppTests
//
//  Настройки панели вкладок: опциональные Календарь / Матрица / Привычки.

import Foundation
import Testing
@testable import BraineeApp

struct TabBarSettingsTests {

    @Test func дефолт_порядокИФлаги() {
        // Задачи и Профиль всегда; календарь вкл., матрица и привычки выкл.
        let settings = TabBarSettings.default
        #expect(settings.showCalendar == true)
        #expect(settings.showMatrix == false)
        #expect(settings.showHabits == false)
        #expect(
            MainTab.visibleTabs(showCalendar: true, showMatrix: false, showHabits: false)
                == [.tasks, .calendar, .profile]
        )
        #expect(
            MainTab.visibleTabs(showCalendar: true, showMatrix: true, showHabits: true)
                == [.tasks, .calendar, .matrix, .habits, .profile]
        )
        #expect(
            MainTab.visibleTabs(showCalendar: false, showMatrix: true, showHabits: true)
                == [.tasks, .matrix, .habits, .profile]
        )
    }

    @Test func сохранениеИЗагрузка_возвращаютФлаги() {
        let suite = "TabBarSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        TabBarSettings(showCalendar: false, showMatrix: true, showHabits: true)
            .save(defaults: defaults)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded.showCalendar == false)
        #expect(loaded.showMatrix == true)
        #expect(loaded.showHabits == true)
    }

    @Test func битыйJSON_loadВозвращаетDefault() {
        let suite = "TabBarSettingsTests.broken.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(Data("not-json".utf8), forKey: TabBarSettings.storageKey)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded == .default)
    }

    @Test func старыйJSONТолькоСМатрицей_календарьПоУмолчаниюВключён() throws {
        // Обратная совместимость: в файле только showMatrix.
        let suite = "TabBarSettingsTests.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacy = Data(#"{"showMatrix":true}"#.utf8)
        defaults.set(legacy, forKey: TabBarSettings.storageKey)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded.showCalendar == true)
        #expect(loaded.showMatrix == true)
        #expect(loaded.showHabits == false)
    }
}
