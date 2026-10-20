//
//  SecretStore.swift
//  BraineeApp
//
//  Секреты (API-ключи) в отдельном Keychain service (LLM-1, D-02, D-28).
//  Только это устройство, в бэкап не входят. Значения никогда не логируются.

import Foundation

/// Имена секретов (account в Keychain).
enum SecretKey: String, CaseIterable {
    case openRouterAPIKey = "openrouter-api-key"
}

struct SecretStore {
    static let defaultService = "\(Bundle.main.bundleIdentifier ?? "BraineeApp").secrets"
    static let shared = SecretStore()

    let service: String

    init(service: String = SecretStore.defaultService) {
        self.service = service
    }

    enum SecretStoreError: Error, Equatable {
        /// Пустое значение или значение с пробелами внутри.
        case invalidValue
        case keychain(OSStatus)
    }

    /// Ключ без пробелов по краям; `nil`, если пустой или с пробелами/переводами строк внутри.
    static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        return trimmed
    }

    /// Для показа в интерфейсе: только последние 4 символа.
    static func masked(_ value: String) -> String {
        "••••" + String(value.suffix(4))
    }

    func value(for key: SecretKey) -> String? {
        guard let data = KeychainStorage.load(account: key.rawValue, service: service) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func hasValue(for key: SecretKey) -> Bool {
        value(for: key) != nil
    }

    /// Сохраняет (или заменяет) секрет.
    func set(_ value: String, for key: SecretKey) throws {
        guard let normalized = Self.normalized(value) else { throw SecretStoreError.invalidValue }
        do {
            try KeychainStorage.save(Data(normalized.utf8), account: key.rawValue, service: service)
        } catch KeychainStorage.KeychainStorageError.saveFailed(let status) {
            throw SecretStoreError.keychain(status)
        }
    }

    /// Удаляет секрет. `true` — был и удалён, `false` — его не было.
    @discardableResult
    func remove(_ key: SecretKey) throws -> Bool {
        do {
            return try KeychainStorage.delete(account: key.rawValue, service: service)
        } catch KeychainStorage.KeychainStorageError.deleteFailed(let status) {
            throw SecretStoreError.keychain(status)
        }
    }
}
