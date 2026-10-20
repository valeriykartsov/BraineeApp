//
//  SecretStoreTests.swift
//  BraineeAppTests
//
//  LLM-1: секреты в изолированном Keychain service; настоящий ключ приложения не затрагивается.

import Foundation
import Testing
@testable import BraineeApp

struct SecretStoreTests {
    private let store = SecretStore(service: "BraineeAppTests.secrets.\(UUID().uuidString)")

    private func cleanUp() {
        for key in SecretKey.allCases {
            _ = try? store.remove(key)
        }
    }

    // Пустое хранилище: ключа нет, удаление сообщает, что удалять было нечего.
    @Test func безКлюча_значенияНетУдалениеВозвращаетFalse() throws {
        defer { cleanUp() }
        #expect(store.value(for: .openRouterAPIKey) == nil)
        #expect(store.hasValue(for: .openRouterAPIKey) == false)
        #expect(try store.remove(.openRouterAPIKey) == false)
    }

    // Сохранённый ключ читается обратно без пробелов по краям.
    @Test func сохранение_читаетсяБезПробеловПоКраям() throws {
        defer { cleanUp() }
        try store.set("  sk-or-v1-abc123\n", for: .openRouterAPIKey)
        #expect(store.value(for: .openRouterAPIKey) == "sk-or-v1-abc123")
        #expect(store.hasValue(for: .openRouterAPIKey))
    }

    // Повторное сохранение заменяет ключ, а не добавляет второй.
    @Test func повторноеСохранение_заменяетКлюч() throws {
        defer { cleanUp() }
        try store.set("sk-or-old", for: .openRouterAPIKey)
        try store.set("sk-or-new", for: .openRouterAPIKey)
        #expect(store.value(for: .openRouterAPIKey) == "sk-or-new")
        #expect(try store.remove(.openRouterAPIKey) == true)
        #expect(store.value(for: .openRouterAPIKey) == nil)
    }

    // Пустой ключ и ключ с пробелами внутри не сохраняются, прежний ключ остаётся.
    @Test func недопустимоеЗначение_ошибкаПрежнийКлючСохранён() throws {
        defer { cleanUp() }
        try store.set("sk-or-keep", for: .openRouterAPIKey)
        #expect(throws: SecretStore.SecretStoreError.invalidValue) {
            try store.set("   ", for: .openRouterAPIKey)
        }
        #expect(throws: SecretStore.SecretStoreError.invalidValue) {
            try store.set("sk-or abc", for: .openRouterAPIKey)
        }
        #expect(store.value(for: .openRouterAPIKey) == "sk-or-keep")
    }

    // Отдельный service: ключ одного хранилища не виден другому.
    @Test func разныеService_неВидятКлючиДругДруга() throws {
        defer { cleanUp() }
        let other = SecretStore(service: "BraineeAppTests.secrets.\(UUID().uuidString)")
        try store.set("sk-or-mine", for: .openRouterAPIKey)
        #expect(other.value(for: .openRouterAPIKey) == nil)
    }

    // В интерфейсе видны только последние 4 символа.
    @Test func маска_показываетТолькоПоследние4Символа() {
        #expect(SecretStore.masked("sk-or-v1-abcdef1234") == "••••1234")
        #expect(SecretStore.masked("abc") == "••••abc")
    }

    // Сервис по умолчанию отделён от остальных записей приложения.
    @Test func serviceПоУмолчанию_заканчиваетсяНаSecrets() {
        #expect(SecretStore.defaultService.hasSuffix(".secrets"))
    }
}
