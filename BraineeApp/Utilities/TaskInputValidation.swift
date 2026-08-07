//
//  TaskInputValidation.swift
//  BraineeApp
//
//  Общие правила проверки ввода: название задачи, описание, имя тега.
//  Вынесено отдельно, чтобы те же правила проверялись юнит-тестами.

import Foundation

enum TaskInputValidation {
    /// Максимум символов в описании задачи (как в форме).
    static let detailsMaxLength = 200

    /// Название можно сохранить, если после обрезки пробелов оно не пустое.
    static func canSaveTitle(_ title: String) -> Bool {
        !normalizedTitle(title).isEmpty
    }

    static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedDetails(_ details: String) -> String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Обрезает описание до лимита (защита на случай обхода UI).
    static func clampedDetails(_ details: String) -> String {
        let trimmed = normalizedDetails(details)
        guard trimmed.count > detailsMaxLength else { return trimmed }
        return String(trimmed.prefix(detailsMaxLength))
    }

    /// Имя тега допустимо: не пустое и не дубликат без учёта регистра.
    static func canCreateTag(name: String, existingNames: [String]) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !existingNames.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    /// Переименование тега: пустое нельзя; дубликат нельзя, кроме текущего имени.
    static func canRenameTag(name: String, existingNames: [String], currentName: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.caseInsensitiveCompare(currentName) == .orderedSame {
            return true
        }
        return canCreateTag(name: trimmed, existingNames: existingNames)
    }

    /// Название группы: не пустое после trim.
    static func canSaveGroupName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedGroupName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
