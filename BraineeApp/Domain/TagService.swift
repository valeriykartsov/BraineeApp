//
//  TagService.swift
//  BraineeApp
//
//  Библиотека тегов (roadmap DOM-2): создание, переименование, удаление.
//  Раньше логика жила в TagLibraryView.

import Foundation
import SwiftData

@MainActor
struct TagService {
    let context: ModelContext
    /// См. TaskService.onChange.
    var onChange: (ModelContext) -> Void = { $0.persistToJSON() }

    private var existingNames: [String] {
        ((try? context.fetch(FetchDescriptor<TaskTag>())) ?? []).map(\.name)
    }

    /// Возвращает nil, если имя пустое или такой тег уже есть.
    @discardableResult
    func create(name: String) -> TaskTag? {
        guard TaskInputValidation.canCreateTag(name: name, existingNames: existingNames) else { return nil }
        let tag = TaskTag(name: TaskInputValidation.normalizedTagName(name))
        context.insert(tag)
        onChange(context)
        return tag
    }

    /// Возвращает false, если имя не прошло проверку (тег не изменён).
    @discardableResult
    func rename(_ tag: TaskTag, to name: String) -> Bool {
        guard TaskInputValidation.canRenameTag(
            name: name,
            existingNames: existingNames,
            currentName: tag.name
        ) else { return false }
        tag.name = TaskInputValidation.normalizedTagName(name)
        onChange(context)
        return true
    }

    /// Тег снимается со всех задач (связь обнуляется), сами задачи не меняются.
    func delete(_ tag: TaskTag) {
        context.delete(tag)
        onChange(context)
    }
}
