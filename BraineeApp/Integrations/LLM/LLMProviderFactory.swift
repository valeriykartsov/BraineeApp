//
//  LLMProviderFactory.swift
//  BraineeApp
//
//  Откуда сценарии чата берут модель: OpenRouter с ключом из Keychain или, только в отладочной
//  сборке с аргументом запуска `-LLMStub`, заглушка с готовыми ответами (проверка чата в
//  симуляторе без ключа и сети). В Release заглушки нет.

import Foundation

enum LLMProviderFactory {
    static let stubLaunchArgument = "-LLMStub"

    /// Включена ли отладочная заглушка (всегда `false` в Release).
    static var isStubEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains(stubLaunchArgument)
#else
        false
#endif
    }

    /// Можно ли пользоваться чатом: есть ключ или включена заглушка.
    static var isAvailable: Bool {
        isStubEnabled || SecretStore.shared.hasValue(for: .openRouterAPIKey)
    }

    static func make() throws -> LLMProvider {
#if DEBUG
        if isStubEnabled { return DebugStubLLMProvider() }
#endif
        return try OpenRouterProvider.fromSettings()
    }
}

#if DEBUG
/// Готовые ответы по словам в тексте пользователя:
/// «ошибка» — нет сети, «мусор» — ответ не в формате JSON.
struct DebugStubLLMProvider: LLMProvider {
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await Task.sleep(nanoseconds: 400_000_000)
        let user = request.messages.last { $0.role == .user }?.content.lowercased() ?? ""

        if user.contains("ошибка") { throw LLMError.offline }
        if user.contains("мусор") { return LLMResponse(text: "Не могу помочь.", model: "debug/stub") }

        return LLMResponse(text: """
        {"title": "Тестовая задача из заглушки", "details": "Ответ отладочной заглушки", \
        "date": "\(Self.day(offset: 1))", "time": "09:30", "priority": "high", "tags": [], "group": null}
        """, model: "debug/stub")
    }

    private static func day(offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
#endif
