//
//  DashboardTaskOrderTests.swift
//  BraineeAppTests
//
//  Порядок задач в группах подробностей дашборда (п. 42).

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct DashboardTaskOrderTests {
    /// Контейнер живёт столько же, сколько тест (см. CLAUDE.md).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func task(_ title: String, status: TaskStatus = .new, trashed: Bool = false) -> TaskItem {
        let task = TaskItem(title: title)
        container.mainContext.insert(task)
        task.status = status
        task.isSoftDeleted = trashed
        return task
    }

    // Актуальные (новые и в работе) выше выполненных, выполненные — выше корзины.
    @Test func смешанныеЗадачи_актуальныеВыполненныеКорзина() {
        let tasks = [
            task("А удалённая", trashed: true),
            task("Б готова", status: .done),
            task("В новая"),
            task("Г в работе", status: .inProgress)
        ]

        let titles = DashboardTaskOrder.sorted(tasks).map(\.title)

        #expect(titles == ["В новая", "Г в работе", "Б готова", "А удалённая"])
    }

    // Внутри каждой части — по названию без учёта регистра.
    @Test func внутриЧасти_поНазванию() {
        let tasks = [
            task("яблоко"),
            task("Банан"),
            task("Вишня", status: .done),
            task("арбуз", status: .done),
            task("Груша", trashed: true),
            task("дыня", status: .done, trashed: true)
        ]

        let titles = DashboardTaskOrder.sorted(tasks).map(\.title)

        #expect(titles == ["Банан", "яблоко", "арбуз", "Вишня", "Груша", "дыня"])
    }

    // Выполненная задача в корзине — в части «в корзине», а не «выполненные».
    @Test func выполненнаяВКорзине_вЧастиКорзина() {
        let tasks = [task("Удалённая готовая", status: .done, trashed: true), task("Готовая", status: .done)]

        #expect(DashboardTaskOrder.rank(of: tasks[0]) == 2)
        #expect(DashboardTaskOrder.sorted(tasks).map(\.title) == ["Готовая", "Удалённая готовая"])
    }
}
