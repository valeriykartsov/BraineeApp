//
//  LLMSettingsTests.swift
//  BraineeAppTests
//
//  LLM-1: модель OpenRouter в UserDefaults — значение по умолчанию, сохранение, проверка формата.

import Foundation
import Testing
@testable import BraineeApp

struct LLMSettingsTests {

    private func makeSuite() -> UserDefaults {
        let name = "LLMSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // Без настройки — автоматический выбор модели OpenRouter.
    @Test func поУмолчанию_openrouterAuto() {
        #expect(LLMSettings.model(defaults: makeSuite()) == "openrouter/auto")
    }

    // Сохранённая модель читается обратно без пробелов по краям; суффикс `:free` допустим.
    @Test func сохранение_читаетсяОбратно() {
        let defaults = makeSuite()
        #expect(LLMSettings.setModel("  meta-llama/llama-3.3-70b-instruct:free ", defaults: defaults))
        #expect(LLMSettings.model(defaults: defaults) == "meta-llama/llama-3.3-70b-instruct:free")
    }

    // Недопустимое значение не сохраняется, прежняя модель остаётся.
    @Test func недопустимаяМодель_неСохраняется() {
        let defaults = makeSuite()
        LLMSettings.setModel("openai/gpt-4o-mini", defaults: defaults)
        for invalid in ["", "   ", "gpt-4o", "/gpt", "openai/", "openai/gpt 4o"] {
            #expect(LLMSettings.setModel(invalid, defaults: defaults) == false, "\(invalid)")
        }
        #expect(LLMSettings.model(defaults: defaults) == "openai/gpt-4o-mini")
    }

    // Испорченное значение в UserDefaults заменяется моделью по умолчанию.
    @Test func испорченноеЗначение_моделиПоУмолчанию() {
        let defaults = makeSuite()
        defaults.set("bad value", forKey: LLMSettings.modelKey)
        #expect(LLMSettings.model(defaults: defaults) == LLMSettings.defaultModel)
    }

    // Подсказка о формате ключа: `sk-or-…` — похоже на ключ OpenRouter.
    @Test func форматКлюча_распознаётПрефиксSkOr() {
        #expect(LLMSettings.looksLikeOpenRouterKey("sk-or-v1-abc"))
        #expect(LLMSettings.looksLikeOpenRouterKey("sk-proj-abc") == false)
    }
}
