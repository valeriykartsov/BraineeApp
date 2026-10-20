//
//  KeychainStorage.swift
//  BraineeApp
//
//  Обёртка над Keychain (generic password). Keychain — только для секретов (API-ключи, токены);
//  данные приложения здесь больше не хранятся (SD-6, D-02).

import Foundation
import Security

enum KeychainStorage {
    static func save(_ data: Data, account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStorageError.saveFailed(status)
        }
    }

    static func load(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    /// Удаляет запись. `true` — запись была и удалена, `false` — её не было.
    @discardableResult
    static func delete(account: String, service: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw KeychainStorageError.deleteFailed(status)
        }
    }

    enum KeychainStorageError: Error {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
    }
}
