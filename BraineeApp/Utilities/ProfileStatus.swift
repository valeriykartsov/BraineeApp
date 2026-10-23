//
//  ProfileStatus.swift
//  BraineeApp
//
//  Текстовый статус профиля (п. 35, D-45): короткая строка о себе под именем.
//  Хранится в UserDefaults (как тема и акцент) и входит в бэкап; не уходит в LLM, виджеты и «Поделиться».

import Foundation

enum ProfileStatus {
    static let storageKey = "profileStatus"
    static let maxLength = 60

    /// Одна строка: переносы — пробелами, без пробелов по краям, не длиннее 60 символов.
    static func normalized(_ text: String) -> String {
        let oneLine = text.components(separatedBy: .newlines).joined(separator: " ")
        let trimmed = oneLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }

    static func load(defaults: UserDefaults = .standard) -> String {
        normalized(defaults.string(forKey: storageKey) ?? "")
    }

    /// Пустой статус — ключ удаляется.
    static func save(_ text: String, defaults: UserDefaults = .standard) {
        let value = normalized(text)
        if value.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(value, forKey: storageKey)
        }
    }
}
