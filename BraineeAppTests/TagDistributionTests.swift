//
//  TagDistributionTests.swift
//  BraineeAppTests
//
//  Доли тегов для круговой диаграммы дашборда.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TagDistributionTests {
    /// Контейнер живёт столько же, сколько тест (см. CLAUDE.md).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func task(_ title: String, tags: [TaskTag]) -> TaskItem {
        let task = TaskItem(title: title)
        container.mainContext.insert(task)
        task.tags = tags
        return task
    }

    // Нет задач — нет секторов.
    @Test func нетЗадач_пустойСписок() {
        #expect(TagDistribution.compute(from: []).isEmpty)
    }

    // Задача с двумя тегами даёт отметку каждому; задача без тегов — сектор «Без тега» в конце.
    @Test func несколькоТегов_считаютсяОтметки() throws {
        let work = TaskTag(name: "работа")
        let calls = TaskTag(name: "звонки")
        container.mainContext.insert(work)
        container.mainContext.insert(calls)
        let tasks = [
            task("Обе", tags: [work, calls]),
            task("Работа", tags: [work]),
            task("Без тегов", tags: [])
        ]

        let shares = TagDistribution.compute(from: tasks)

        #expect(shares.map(\.name) == ["работа", "звонки", TagDistribution.untaggedName])
        #expect(shares.map(\.count) == [2, 1, 1])
        #expect(shares.map(\.percent) == [50, 25, 25])
        #expect(shares.last?.isUntagged == true)
    }

    // Тег с именем «Без тега» не сливается с сектором задач без тегов.
    @Test func тегСИменемБезТега_отдельныйСектор() {
        let named = TaskTag(name: TagDistribution.untaggedName)
        container.mainContext.insert(named)
        let tasks = [task("С тегом", tags: [named]), task("Без тегов", tags: [])]

        let shares = TagDistribution.compute(from: tasks)

        #expect(shares.count == 2)
        #expect(Set(shares.map(\.id)).count == 2)
    }

    // Проценты целые и в сумме ровно 100, даже при трёх равных долях.
    @Test func проценты_суммаРовно100() {
        #expect(TagDistribution.roundedPercents([1, 1, 1]) == [34, 33, 33])
        #expect(TagDistribution.roundedPercents([2, 1]) == [67, 33])
        #expect(TagDistribution.roundedPercents([5, 3, 2, 1]).reduce(0, +) == 100)
        #expect(TagDistribution.roundedPercents([0, 0]) == [0, 0])
    }
}
