//
//  TabBarSettingsTests.swift
//  BraineeAppTests
//
//  Настройки панели вкладок: опциональные Календарь / LLM / Привычки.
//  NAV-1: вкладка «LLM» заменила «Матрицу», прежний флаг Матрицы переносится.

import Foundation
import Testing
@testable import BraineeApp

struct TabBarSettingsTests {

    private func makeSuite() -> UserDefaults {
        let name = "TabBarSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func дефолт_порядокИФлаги() {
        // Задачи и Профиль всегда; календарь вкл., LLM и привычки выкл.
        let settings = TabBarSettings.default
        #expect(settings.showCalendar == true)
        #expect(settings.showLLM == false)
        #expect(settings.showHabits == false)
        #expect(
            MainTab.visibleTabs(showCalendar: true, showLLM: false, showHabits: false)
                == [.tasks, .calendar, .profile]
        )
        #expect(
            MainTab.visibleTabs(showCalendar: true, showLLM: true, showHabits: true)
                == [.tasks, .calendar, .llm, .habits, .profile]
        )
        #expect(
            MainTab.visibleTabs(showCalendar: false, showLLM: true, showHabits: true)
                == [.tasks, .llm, .habits, .profile]
        )
    }

    // Вкладка LLM: название и иконка.
    @Test func вкладкаLLM_названиеИИконка() {
        #expect(MainTab.llm.title == "LLM")
        #expect(MainTab.llm.systemImage == "sparkles")
    }

    @Test func сохранениеИЗагрузка_возвращаютФлаги() {
        let defaults = makeSuite()
        TabBarSettings(showCalendar: false, showLLM: true, showHabits: true)
            .save(defaults: defaults)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded.showCalendar == false)
        #expect(loaded.showLLM == true)
        #expect(loaded.showHabits == true)
        #expect(defaults.bool(forKey: TabBarSettings.showLLMKey) == true)
    }

    @Test func битыйJSON_loadВозвращаетDefault() {
        let defaults = makeSuite()
        defaults.set(Data("not-json".utf8), forKey: TabBarSettings.storageKey)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded == .default)
    }

    @Test func старыйJSONТолькоСМатрицей_календарьВключёнLLMПоФлагуМатрицы() throws {
        // Обратная совместимость: в JSON только прежний showMatrix — он становится showLLM.
        let defaults = makeSuite()
        defaults.set(Data(#"{"showMatrix":true}"#.utf8), forKey: TabBarSettings.storageKey)
        let loaded = TabBarSettings.load(defaults: defaults)
        #expect(loaded.showCalendar == true)
        #expect(loaded.showLLM == true)
        #expect(loaded.showHabits == false)
    }

    // Новый JSON пишет showLLM и не пишет прежний showMatrix.
    @Test func json_пишетShowLLMБезShowMatrix() throws {
        let data = try JSONEncoder().encode(TabBarSettings(showCalendar: true, showLLM: true, showHabits: false))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Bool])
        #expect(json == ["showCalendar": true, "showLLM": true, "showHabits": false])
    }

    // Матрица была на панели → после обновления на её месте LLM.
    @Test func переносФлагаМатрицы_включённаяМатрицаДаётLLM() {
        let defaults = makeSuite()
        defaults.set(true, forKey: TabBarSettings.legacyShowMatrixKey)
        TabBarSettings.migrateLegacyMatrixFlag(defaults: defaults)
        #expect(defaults.object(forKey: TabBarSettings.showLLMKey) as? Bool == true)
        #expect(TabBarSettings.load(defaults: defaults).showLLM == true)
    }

    // Матрица была скрыта → LLM тоже скрыта.
    @Test func переносФлагаМатрицы_выключеннаяМатрицаДаётВыключенныйLLM() {
        let defaults = makeSuite()
        defaults.set(false, forKey: TabBarSettings.legacyShowMatrixKey)
        TabBarSettings.migrateLegacyMatrixFlag(defaults: defaults)
        #expect(defaults.object(forKey: TabBarSettings.showLLMKey) as? Bool == false)
    }

    // Уже выбранный флаг LLM не перезаписывается прежним флагом Матрицы (повторный запуск).
    @Test func переносФлагаМатрицы_неПеретираетФлагLLM() {
        let defaults = makeSuite()
        defaults.set(true, forKey: TabBarSettings.legacyShowMatrixKey)
        defaults.set(false, forKey: TabBarSettings.showLLMKey)
        TabBarSettings.migrateLegacyMatrixFlag(defaults: defaults)
        #expect(defaults.bool(forKey: TabBarSettings.showLLMKey) == false)
        #expect(TabBarSettings.load(defaults: defaults).showLLM == false)
    }

    // Новая установка: ни одного флага — перенос ничего не пишет, LLM по умолчанию скрыта.
    @Test func переносФлагаМатрицы_безФлаговНичегоНеПишет() {
        let defaults = makeSuite()
        TabBarSettings.migrateLegacyMatrixFlag(defaults: defaults)
        #expect(defaults.object(forKey: TabBarSettings.showLLMKey) == nil)
        #expect(TabBarSettings.load(defaults: defaults).showLLM == false)
    }
}
