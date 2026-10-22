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
    var onChange: (ModelContext) -> Void = { $0.didChange() }
    /// Текущее время для updatedAt; в тестах подменяется фиксированной датой.
    var now: () -> Date = { .now }
    /// Журнал сессии (п. 16); в тестах — свой экземпляр.
    var log: SessionLog = .shared

    private var existingNames: [String] {
        ((try? context.fetch(FetchDescriptor<TaskTag>())) ?? []).map(\.name)
    }

    /// Возвращает nil, если имя пустое или такой тег уже есть.
    @discardableResult
    func create(name: String) -> TaskTag? {
        guard TaskInputValidation.canCreateTag(name: name, existingNames: existingNames) else { return nil }
        let tag = TaskTag(name: TaskInputValidation.normalizedTagName(name), createdAt: now())
        context.insert(tag)
        log.add(.tag, "Тег создан", subject: tag.name)
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
        let oldName = tag.name
        tag.name = TaskInputValidation.normalizedTagName(name)
        if let change = SessionLogDiff.line(nil, SessionLogDiff.quoted(oldName), SessionLogDiff.quoted(tag.name)) {
            log.add(.tag, "Тег переименован", subject: tag.name, changes: [change])
        }
        tag.updatedAt = now()
        onChange(context)
        return true
    }

    /// Тег снимается со всех задач (связь обнуляется); у этих задач обновляется updatedAt.
    func delete(_ tag: TaskTag) {
        let tasks = tag.tasks ?? []
        for task in tasks {
            task.updatedAt = now()
        }
        log.add(
            .tag,
            "Тег удалён",
            subject: tag.name,
            changes: tasks.isEmpty ? [] : ["Снят с задач: \(tasks.count)"]
        )
        context.delete(tag)
        onChange(context)
    }
}
