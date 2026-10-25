//
//  KanbanBoardsTests.swift
//  BraineeAppTests
//
//  Канбан «Разбить по папкам» (п. 44): состав и порядок досок, порядок карточек, настройка.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct KanbanBoardsTests {
    /// Контейнер живёт столько же, сколько тест (см. CLAUDE.md).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func group(_ name: String, order: Int) -> TaskGroup {
        let group = TaskGroup(name: name, sortOrder: order)
        container.mainContext.insert(group)
        return group
    }

    private func task(
        _ title: String,
        in group: TaskGroup? = nil,
        status: TaskStatus = .new,
        priority: TaskPriority = .medium
    ) -> TaskItem {
        let task = TaskItem(title: title, priority: priority)
        container.mainContext.insert(task)
        task.group = group
        task.status = status
        return task
    }

    // Доски — по порядку папок; папка без задач доски не получает; «Входящие» — последней.
    @Test func доски_поПорядкуПапокБезПустыхВходящиеПоследней() {
        let home = group("Дом", order: 1)
        let work = group("Работа", order: 0)
        let empty = group("Пустая", order: 2)
        let tasks = [
            task("Без папки"),
            task("Купить", in: home),
            task("Отчёт", in: work),
            task("Созвон", in: work, status: .inProgress)
        ]

        let boards = KanbanBoards.make(groups: [empty, home, work], tasks: tasks)

        #expect(boards.map(\.title) == ["Работа", "Дом", "Входящие"])
        #expect(boards.map(\.tasks.count) == [2, 1, 1])
        #expect(boards.last?.isInbox == true)
        #expect(boards.first?.tasks(in: .inProgress).map(\.title) == ["Созвон"])
    }

    // Без задач во «Входящих» их доски нет; без задач вообще — досок нет.
    @Test func пустыеВходящие_безДоски() {
        let work = group("Работа", order: 0)

        #expect(KanbanBoards.make(groups: [work], tasks: [task("Отчёт", in: work)]).map(\.title) == ["Работа"])
        #expect(KanbanBoards.make(groups: [work], tasks: []).isEmpty)
    }

    // Доска знает только свои задачи — по этому колонка отказывает в переносе из другой папки.
    @Test func задачаДругойПапки_неПринадлежитДоске() {
        let work = group("Работа", order: 0)
        let home = group("Дом", order: 1)
        let report = task("Отчёт", in: work)
        let shop = task("Купить", in: home)

        let boards = KanbanBoards.make(groups: [work, home], tasks: [report, shop])

        #expect(boards[0].contains(report))
        #expect(!boards[0].contains(shop))
        #expect(boards[0].id != boards[1].id)
    }

    // Порядок карточек в колонке — как раньше: по приоритету, затем по названию; или по названию.
    @Test func сортировкаКолонки_поПриоритетуИНазванию() {
        let tasks = [
            task("Б низкий", priority: .low),
            task("В наивысший", priority: .highest),
            task("А низкий", priority: .low)
        ]

        #expect(KanbanSortMode.priority.sorted(tasks).map(\.title) == ["В наивысший", "А низкий", "Б низкий"])
        #expect(KanbanSortMode.title.sorted(tasks).map(\.title) == ["А низкий", "Б низкий", "В наивысший"])
    }

    // «Разбить по папкам» по умолчанию выключено, в том числе в старых настройках без ключа; смена — в журнале.
    @Test func настройка_поУмолчаниюВыключенаИПишетсяВЖурнал() throws {
        let json = #"{"showDetails":true,"showDeadline":true,"showPriority":true,"showStatus":true,"showTags":true}"#
        let decoded = try JSONDecoder().decode(TaskListDisplaySettings.self, from: Data(json.utf8))
        #expect(decoded.kanbanByFolder == false)
        #expect(TaskListDisplaySettings.default.kanbanByFolder == false)

        var new = TaskListDisplaySettings.default
        new.kanbanByFolder = true
        let lines = SettingsChangeObserver.Setting.displayChanges(.default, new)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("Канбан по папкам") == true)
    }
}
