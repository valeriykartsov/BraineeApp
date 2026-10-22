//
//  GroupService.swift
//  BraineeApp
//
//  Группы (папки) задач (roadmap DOM-2): создание, переименование, удаление.
//  Раньше логика жила в TaskSectionView и TaskOrganizedListView.

import Foundation
import SwiftData

@MainActor
struct GroupService {
    let context: ModelContext
    /// См. TaskService.onChange.
    var onChange: (ModelContext) -> Void = { $0.didChange() }
    /// Текущее время для updatedAt; в тестах подменяется фиксированной датой.
    var now: () -> Date = { .now }
    /// Журнал сессии (п. 16); в тестах — свой экземпляр.
    var log: SessionLog = .shared

    /// Новая группа — в конец списка. Пустое имя не создаёт группу.
    @discardableResult
    func create(name: String) -> TaskGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let groups = (try? context.fetch(FetchDescriptor<TaskGroup>())) ?? []
        let nextOrder = (groups.map(\.sortOrder).max() ?? -1) + 1
        let group = TaskGroup(name: trimmed, category: .tasks, sortOrder: nextOrder, createdAt: now())
        context.insert(group)
        log.add(.group, "Папка создана", subject: group.name)
        onChange(context)
        return group
    }

    /// Возвращает false, если имя не прошло проверку (группа не изменена).
    @discardableResult
    func rename(_ group: TaskGroup, to name: String) -> Bool {
        guard TaskInputValidation.canSaveGroupName(name) else { return false }
        let oldName = group.name
        group.name = TaskInputValidation.normalizedGroupName(name)
        if let change = SessionLogDiff.line(nil, SessionLogDiff.quoted(oldName), SessionLogDiff.quoted(group.name)) {
            log.add(.group, "Папка переименована", subject: group.name, changes: [change])
        }
        group.updatedAt = now()
        onChange(context)
        return true
    }

    /// Удаление папки не удаляет задачи: они переходят во «Входящие», включая задачи в корзине.
    /// У таких задач меняется группа, поэтому обновляется их updatedAt.
    func delete(_ group: TaskGroup) {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        var movedCount = 0
        for task in tasks where task.group?.uuid == group.uuid {
            task.group = nil
            task.updatedAt = now()
            movedCount += 1
        }
        log.add(
            .group,
            "Папка удалена",
            subject: group.name,
            changes: movedCount > 0 ? ["Задачи перенесены во «Входящие»: \(movedCount)"] : []
        )
        context.delete(group)
        onChange(context)
    }
}
