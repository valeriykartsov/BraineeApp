//
//  GroupCollapseLogic.swift
//  BraineeApp
//
//  Свернуть / развернуть все группы: какое действие следующее и как применить.

import Foundation

enum GroupCollapseLogic {
    /// Группы, которые можно свернуть (есть хотя бы одна задача).
    static func collapsibleIDs(
        groups: [TaskGroup],
        tasks: [TaskItem]
    ) -> Set<UUID> {
        var counts: [UUID: Int] = [:]
        for task in tasks {
            guard let id = task.group?.uuid else { continue }
            counts[id, default: 0] += 1
        }
        return Set(groups.compactMap { group in
            (counts[group.uuid] ?? 0) > 0 ? group.uuid : nil
        })
    }

    /// true → следующее нажатие разворачивает оставшиеся; false → сворачивает открытые.
    static func nextActionIsExpand(
        collapsibleIDs: Set<UUID>,
        collapsedIDs: Set<UUID>
    ) -> Bool {
        guard !collapsibleIDs.isEmpty else { return true }
        // Все раскрыты → сворачиваем; иначе (все/часть свёрнуты) → раскрываем оставшиеся.
        let allExpanded = collapsibleIDs.allSatisfy { !collapsedIDs.contains($0) }
        return !allExpanded
    }

    /// Раскрыть все: убрать из свёрнутых только collapsible (остальные id не трогаем).
    static func expanding(
        collapsibleIDs: Set<UUID>,
        collapsedIDs: Set<UUID>
    ) -> Set<UUID> {
        collapsedIDs.subtracting(collapsibleIDs)
    }

    /// Свернуть все: добавить collapsible в свёрнутые (уже свёрнутые остаются).
    static func collapsing(
        collapsibleIDs: Set<UUID>,
        collapsedIDs: Set<UUID>
    ) -> Set<UUID> {
        collapsedIDs.union(collapsibleIDs)
    }
}
