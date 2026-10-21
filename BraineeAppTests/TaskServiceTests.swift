//
//  TaskServiceTests.swift
//  BraineeAppTests
//
//  TaskService (roadmap DOM-1): правила изменения задач, общие для всех экранов.
//  onChange подменён счётчиком — тесты не пишут настоящие JSON, Keychain и уведомления.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskServiceTests {
    /// Контейнер живёт столько же, сколько тест: локальную переменную Swift может освободить
    /// сразу после последнего использования, и обращение к моделям после этого роняет процесс.
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    /// Счётчик вызовов onChange (сохранение после изменения).
    private final class ChangeCounter {
        var count = 0
    }

    private func makeService(_ context: ModelContext, counter: ChangeCounter) -> TaskService {
        TaskService(context: context, onChange: { _ in counter.count += 1 })
    }

    private func form(
        title: String = "Задача",
        deadline: Date? = nil,
        status: TaskStatus = .new,
        tags: [TaskTag] = []
    ) -> TaskFormData {
        TaskFormData(
            title: title,
            deadline: deadline,
            hasDeadlineTime: deadline != nil,
            reminderOffsets: deadline != nil ? [.minutes15] : [],
            priority: .high,
            status: status,
            taskDetails: "описание",
            selectedTags: tags
        )
    }

    // MARK: - Создание

    // Новая задача получает все поля формы, статус «Новая» и сохраняется один раз.
    @Test func создание_переноситПоляФормыИСохраняет() throws {
        let context = container.mainContext
        let counter = ChangeCounter()
        let tag = TaskTag(name: "работа")
        context.insert(tag)
        let deadline = TestHelpers.daysFromNow(1)

        let task = makeService(context, counter: counter)
            .create(from: form(title: "Купить хлеб", deadline: deadline, status: .done, tags: [tag]))

        #expect(task.title == "Купить хлеб")
        #expect(task.deadline == deadline)
        #expect(task.hasDeadlineTime)
        #expect(task.reminderOffsets == [.minutes15])
        #expect(task.priority == .high)
        #expect(task.taskDetails == "описание")
        #expect(task.tags.map(\.uuid) == [tag.uuid])
        // Как и раньше в TaskSectionView: статус формы при создании игнорируется.
        #expect(task.status == .new)
        #expect(context.fetchActiveTasks().contains { $0.uuid == task.uuid })
        #expect(counter.count == 1)
    }

    // Новая задача встаёт в конец: sortOrder больше максимального среди активных.
    @Test func создание_ставитЗадачуВКонец() throws {
        let context = container.mainContext
        context.insert(TaskItem(title: "Первая", sortOrder: 4))
        context.insert(TaskItem(title: "Вторая", sortOrder: 9))
        // Задача в корзине не влияет на порядок активных.
        context.insert(TaskItem(title: "В корзине", sortOrder: 50, isSoftDeleted: true, deletedAt: .now))

        let task = makeService(context, counter: ChangeCounter()).create(from: form())

        #expect(task.sortOrder == 10)
    }

    // Первая задача в пустом приложении получает sortOrder 0.
    @Test func создание_перваяЗадача_порядокНоль() throws {
        let task = makeService(container.mainContext, counter: ChangeCounter()).create(from: form())

        #expect(task.sortOrder == 0)
    }

    // MARK: - Редактирование

    // Редактирование переносит все поля формы, включая статус и теги.
    @Test func редактирование_обновляетВсеПоля() throws {
        let context = container.mainContext
        let counter = ChangeCounter()
        let task = TaskItem(title: "Старое", priority: .low)
        let tag = TaskTag(name: "дом")
        context.insert(task)
        context.insert(tag)
        let deadline = TestHelpers.daysFromNow(2)

        makeService(context, counter: counter)
            .update(task, from: form(title: "Новое", deadline: deadline, status: .inProgress, tags: [tag]))

        #expect(task.title == "Новое")
        #expect(task.deadline == deadline)
        #expect(task.priority == .high)
        #expect(task.status == .inProgress)
        #expect(task.taskDetails == "описание")
        #expect(task.tags.map(\.uuid) == [tag.uuid])
        #expect(counter.count == 1)
    }

    // Снятие даты в форме убирает и напоминания (правило модели сохраняется через сервис).
    @Test func редактированиеБезДаты_убираетНапоминания() throws {
        let context = container.mainContext
        let task = TaskItem(title: "С датой", deadline: TestHelpers.daysFromNow(1), reminderOffsets: [.hours1])
        context.insert(task)
        var withoutDate = form()
        withoutDate.reminderOffsets = [.hours1]

        makeService(context, counter: ChangeCounter()).update(task, from: withoutDate)

        #expect(task.deadline == nil)
        #expect(task.reminderOffsets.isEmpty)
    }

    // MARK: - Отметка выполнения

    // Выполненная задача уходит в конец своей группы; другие группы не учитываются.
    @Test func выполнение_переноситВКонецСвоейГруппы() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Проект")
        context.insert(group)
        let task = TaskItem(title: "Цель", sortOrder: 0, group: group)
        context.insert(task)
        context.insert(TaskItem(title: "Сосед", sortOrder: 5, group: group))
        context.insert(TaskItem(title: "Без папки", sortOrder: 100))
        let counter = ChangeCounter()

        makeService(context, counter: counter).toggleCompletion(task)

        #expect(task.status == .done)
        #expect(task.isCompleted)
        #expect(task.sortOrder == 6)
        #expect(counter.count == 1)
    }

    // Снятие отметки — в конец незакрытых той же группы (ниже выполненных не опускается).
    @Test func снятиеОтметки_переноситВКонецНезакрытых() throws {
        let context = container.mainContext
        let task = TaskItem(title: "Цель", status: .done, sortOrder: 20)
        context.insert(task)
        context.insert(TaskItem(title: "Активная", sortOrder: 3))
        context.insert(TaskItem(title: "Выполненная", status: .done, sortOrder: 30))

        makeService(context, counter: ChangeCounter()).toggleCompletion(task)

        #expect(task.status == .new)
        #expect(task.sortOrder == 4)
    }

    // Задачи в корзине не считаются соседями при перестановке (иначе sortOrder был бы 100).
    @Test func выполнение_корзинаНеВлияетНаПорядок() throws {
        let context = container.mainContext
        let task = TaskItem(title: "Цель", sortOrder: 0)
        context.insert(task)
        context.insert(TaskItem(title: "В корзине", sortOrder: 99, isSoftDeleted: true, deletedAt: .now))

        makeService(context, counter: ChangeCounter()).toggleCompletion(task)

        #expect(task.sortOrder == 0)
    }

    // MARK: - Статус и удаление

    // Смена статуса из канбана: «Готово» отмечает выполнение, порядок не меняется.
    @Test func сменаСтатуса_синхронизируетВыполнениеБезПерестановки() throws {
        let context = container.mainContext
        let task = TaskItem(title: "Канбан", sortOrder: 2)
        context.insert(task)
        context.insert(TaskItem(title: "Сосед", sortOrder: 8))
        let counter = ChangeCounter()

        makeService(context, counter: counter).setStatus(task, .done)

        #expect(task.status == .done)
        #expect(task.isCompleted)
        #expect(task.sortOrder == 2)
        #expect(counter.count == 1)
    }

    // Мягкое удаление: задача остаётся в базе, но уходит из активных и получает дату удаления.
    @Test func мягкоеУдаление_задачаВКорзинеНоВБазе() throws {
        let context = container.mainContext
        let task = TaskItem(title: "Удалить")
        context.insert(task)
        let counter = ChangeCounter()
        let before = Date.now

        makeService(context, counter: counter).softDelete(task)

        #expect(task.isSoftDeleted)
        #expect((task.deletedAt ?? .distantPast) >= before)
        #expect(context.fetchActiveTasks().isEmpty)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(counter.count == 1)
    }

    // MARK: - Перенос в группу (DOM-2)

    // Перенос в группу ставит задачу в конец этой группы.
    @Test func переносВГруппу_вКонецГруппы() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Проект")
        context.insert(group)
        context.insert(TaskItem(title: "В группе", sortOrder: 7, group: group))
        let task = TaskItem(title: "Без папки", sortOrder: 50)
        context.insert(task)
        let counter = ChangeCounter()

        makeService(context, counter: counter).move(task, to: group)

        #expect(task.group?.uuid == group.uuid)
        #expect(task.sortOrder == 8)
        #expect(counter.count == 1)
    }

    // Перенос во «Входящие» (nil) — в конец задач без группы.
    @Test func переносБезПапки_вКонецБезПапки() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Проект")
        context.insert(group)
        let task = TaskItem(title: "Из группы", sortOrder: 0, group: group)
        context.insert(task)
        context.insert(TaskItem(title: "Без папки", sortOrder: 3))

        makeService(context, counter: ChangeCounter()).move(task, to: nil)

        #expect(task.group == nil)
        #expect(task.sortOrder == 4)
    }

    // Задачу из корзины перенести нельзя: ничего не меняется и не сохраняется.
    @Test func переносЗадачиИзКорзины_игнорируется() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Проект")
        context.insert(group)
        let task = TaskItem(title: "В корзине", sortOrder: 1, isSoftDeleted: true, deletedAt: .now)
        context.insert(task)
        let counter = ChangeCounter()

        makeService(context, counter: counter).move(task, to: group)

        #expect(task.group == nil)
        #expect(task.sortOrder == 1)
        #expect(counter.count == 0)
    }

    // MARK: - Корзина (DOM-2)

    // Восстановление снимает флаг и дату удаления, задача снова активна.
    @Test func восстановление_возвращаетВАктивные() throws {
        let context = container.mainContext
        let task = TaskItem(title: "Вернуть", isSoftDeleted: true, deletedAt: .now)
        context.insert(task)
        let counter = ChangeCounter()

        makeService(context, counter: counter).restore(task)

        #expect(!task.isSoftDeleted)
        #expect(task.deletedAt == nil)
        #expect(context.fetchActiveTasks().map(\.uuid) == [task.uuid])
        #expect(counter.count == 1)
    }

    // Окончательное удаление стирает задачи из корзины, остальные не трогает.
    @Test func окончательноеУдаление_стираетТолькоИзКорзины() throws {
        let context = container.mainContext
        let trashed1 = TaskItem(title: "Корзина 1", isSoftDeleted: true, deletedAt: .now)
        let trashed2 = TaskItem(title: "Корзина 2", isSoftDeleted: true, deletedAt: .now)
        let active = TaskItem(title: "Активная")
        for task in [trashed1, trashed2, active] { context.insert(task) }
        let counter = ChangeCounter()

        makeService(context, counter: counter).permanentlyDelete([trashed1, trashed2])

        let left = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(left.map(\.title) == ["Активная"])
        #expect(counter.count == 1)
    }

    // Защита: активную задачу окончательно удалить нельзя, даже если её передали.
    @Test func окончательноеУдалениеАктивной_игнорируется() throws {
        let context = container.mainContext
        let active = TaskItem(title: "Активная")
        context.insert(active)
        let counter = ChangeCounter()

        makeService(context, counter: counter).permanentlyDelete([active])

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(counter.count == 0)
    }
}
