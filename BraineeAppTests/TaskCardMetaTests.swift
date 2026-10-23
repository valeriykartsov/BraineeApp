//
//  TaskCardMetaTests.swift
//  BraineeAppTests
//
//  Метки карточки задачи (п. 37): срок, статус, приоритет, теги (до 3), подзадачи — в этом порядке;
//  настройки отображения списка соблюдаются.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskCardMetaTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func task(deadline: Date? = nil, tags: [String] = [], subtasks: [Bool] = []) -> TaskItem {
        let item = TaskItem(title: "Отчёт", deadline: deadline, priority: .high)
        context.insert(item)
        item.tags = tags.map { name in
            let tag = TaskTag(name: name)
            context.insert(tag)
            return tag
        }
        item.subtasks = subtasks.enumerated().map { index, isDone in
            let subtask = TaskSubtask(title: "Шаг \(index)", isDone: isDone, sortOrder: index)
            context.insert(subtask)
            return subtask
        }
        return item
    }

    private func settings(
        deadline: Bool = true,
        status: Bool = true,
        priority: Bool = true,
        tags: Bool = true,
        subtasks: Bool = true
    ) -> TaskListDisplaySettings {
        TaskListDisplaySettings(
            showDetails: true,
            showDeadline: deadline,
            showPriority: priority,
            showStatus: status,
            showTags: tags,
            showSubtasks: subtasks
        )
    }

    // Все метки включены: срок, статус, приоритет, теги, подзадачи — именно в этом порядке.
    @Test func всеМетки_вПорядкеПодзадачиПоследними() {
        let item = task(deadline: PersistenceFixtures.date(86_400), tags: ["дом"], subtasks: [true, false])
        let meta = TaskCardMeta(task: item, settings: settings(), overdue: true)

        #expect(meta.chips == [
            .deadline(item.deadlineDisplayText!, overdue: true),
            .status(item.status),
            .priority(.high),
            .tag("дом"),
            .subtasks("☑ 1/2"),
        ])
    }

    // Тегов больше трёх — на карточке только первые три, подзадачи всё равно последние.
    @Test func тегиБольшеТрёх_показываютсяТриПервых() {
        let item = task(tags: ["a", "b", "c", "d"], subtasks: [false])
        let meta = TaskCardMeta(task: item, settings: settings(status: false, priority: false), overdue: false)

        #expect(meta.chips == item.tags.prefix(3).map { .tag($0.name) } + [.subtasks("☑ 0/1")])
    }

    // Без срока и подзадач — этих меток нет, остальные идут по порядку.
    @Test func нетСрокаИПодзадач_меткиБезНих() {
        let item = task()
        let meta = TaskCardMeta(task: item, settings: settings(), overdue: false)

        #expect(meta.chips == [.status(item.status), .priority(.high)])
    }

    // Выключенные в настройках отображения метки не показываются.
    @Test func выключенныеМетки_неПоказываются() {
        let item = task(deadline: PersistenceFixtures.date(86_400), tags: ["дом"], subtasks: [false])
        let meta = TaskCardMeta(task: item, settings: settings(deadline: false, tags: false), overdue: false)

        #expect(meta.chips == [.status(item.status), .priority(.high), .subtasks("☑ 0/1")])
    }

    // Все метки выключены — меток нет совсем.
    @Test func всеМеткиВыключены_метокНет() {
        let item = task(deadline: PersistenceFixtures.date(86_400), tags: ["дом"], subtasks: [false])
        let off = settings(deadline: false, status: false, priority: false, tags: false, subtasks: false)

        #expect(TaskCardMeta(task: item, settings: off, overdue: false).chips.isEmpty)
    }
}
