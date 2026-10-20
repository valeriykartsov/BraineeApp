//
//  LLMSettings.swift
//  BraineeApp
//
//  Настройки LLM (LLM-1, D-24): провайдер — только OpenRouter; модель — в UserDefaults,
//  API-ключ — в Keychain (`SecretStore`), не здесь.

import Foundation

enum LLMSettings {
    static let modelKey = "llmModel"
    /// Модель по умолчанию: автоматический выбор OpenRouter. Меняется в «Профиль → Ещё → LLM».
    static let defaultModel = "openrouter/auto"
    static let modelsCatalogURL = URL(string: "https://openrouter.ai/models")!
    static let keysPageURL = URL(string: "https://openrouter.ai/settings/keys")!

    static func model(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: modelKey).flatMap(normalizedModel) ?? defaultModel
    }

    /// Сохраняет модель. `false` — значение недопустимо, настройка не изменена.
    @discardableResult
    static func setModel(_ value: String, defaults: UserDefaults = .standard) -> Bool {
        guard let model = normalizedModel(value) else { return false }
        defaults.set(model, forKey: modelKey)
        return true
    }

    /// Идентификатор модели OpenRouter вида `vendor/model` (возможен суффикс `:free`):
    /// без пробелов, с `/` не в начале и не в конце.
    static func normalizedModel(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let slash = trimmed.firstIndex(of: "/"),
              slash != trimmed.startIndex,
              trimmed.index(after: slash) != trimmed.endIndex else { return nil }
        return trimmed
    }

    /// Похоже ли значение на ключ OpenRouter (`sk-or-…`). Только подсказка, не запрет.
    static func looksLikeOpenRouterKey(_ value: String) -> Bool {
        value.hasPrefix("sk-or-")
    }
}
