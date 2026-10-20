//
//  GroupAndTagServiceTests.swift
//  BraineeAppTests
//
//  GroupService и TagService (roadmap DOM-2): правила групп и библиотеки тегов.
//  onChange подменён счётчиком — тесты не пишут настоящие JSON, Keychain и уведомления.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct GroupAndTagServiceTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private final class ChangeCounter {
        var count = 0
    }

    private func groups(_ counter: ChangeCounter) -> GroupService {
        GroupService(context: container.mainContext, onChange: { _ in counter.count += 1 })
    }

    private func tags(_ counter: ChangeCounter) -> TagService {
        TagService(context: container.mainContext, onChange: { _ in counter.count += 1 })
    }

    // MARK: - Группы

    // Новая группа: имя без пробелов по краям, в конце списка, сохранение один раз.
    @Test func созданиеГруппы_вКонецСписка() throws {
        let context = container.mainContext
        context.insert(TaskGroup(name: "Первая", sortOrder: 2))
        let counter = ChangeCounter()

        let group = try #require(groups(counter).create(name: "  Проект  "))

        #expect(group.name == "Проект")
        #expect(group.sortOrder == 3)
        #expect(counter.count == 1)
    }

    // Пустое имя группу не создаёт и ничего не сохраняет.
    @Test func созданиеГруппыПустоеИмя_неСоздаёт() throws {
        let counter = ChangeCounter()

        #expect(groups(counter).create(name: "   ") == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<TaskGroup>()).isEmpty)
        #expect(counter.count == 0)
    }

    // Переименование: допустимое имя применяется, пустое — отклоняется без изменений.
    @Test func переименованиеГруппы_пустоеИмяОтклоняется() throws {
        let group = TaskGroup(name: "Старое")
        container.mainContext.insert(group)
        let counter = ChangeCounter()
        let service = groups(counter)

        #expect(service.rename(group, to: "  Новое ") == true)
        #expect(group.name == "Новое")
        #expect(service.rename(group, to: "  ") == false)
        #expect(group.name == "Новое")
        #expect(counter.count == 1)
    }

    // Удаление группы: задачи (активные и из корзины) остаются, но «Без папки».
    @Test func удалениеГруппы_задачиОстаютсяБезПапки() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Проект")
        context.insert(group)
        let active = TaskItem(title: "Активная", group: group)
        let trashed = TaskItem(title: "В корзине", isSoftDeleted: true, deletedAt: .now, group: group)
        context.insert(active)
        context.insert(trashed)
        let counter = ChangeCounter()

        groups(counter).delete(group)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskGroup>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 2)
        #expect(active.group == nil)
        #expect(trashed.group == nil)
        #expect(counter.count == 1)
    }

    // MARK: - Теги

    // Новый тег: имя без пробелов по краям.
    @Test func созданиеТега_обрезаетПробелы() throws {
        let counter = ChangeCounter()

        let tag = try #require(tags(counter).create(name: "  работа "))

        #expect(tag.name == "работа")
        #expect(counter.count == 1)
    }

    // Дубликат (без учёта регистра) и пустое имя тег не создают.
    @Test func созданиеТега_дубликатИПустоеОтклоняются() throws {
        container.mainContext.insert(TaskTag(name: "Работа"))
        let counter = ChangeCounter()
        let service = tags(counter)

        #expect(service.create(name: "работа") == nil)
        #expect(service.create(name: "  ") == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<TaskTag>()).count == 1)
        #expect(counter.count == 0)
    }

    // Переименование: в имя другого тега нельзя, смена регистра своего имени — можно.
    @Test func переименованиеТега_правилаДубликатов() throws {
        let context = container.mainContext
        let home = TaskTag(name: "дом")
        context.insert(home)
        context.insert(TaskTag(name: "работа"))
        let counter = ChangeCounter()
        let service = tags(counter)

        #expect(service.rename(home, to: "Работа") == false)
        #expect(home.name == "дом")
        #expect(service.rename(home, to: "Дом") == true)
        #expect(home.name == "Дом")
        #expect(counter.count == 1)
    }

    // Удаление тега снимает его с задач, задачи остаются.
    @Test func удалениеТега_снимаетСЗадач() throws {
        let context = container.mainContext
        let tag = TaskTag(name: "работа")
        context.insert(tag)
        let task = TaskItem(title: "С тегом")
        context.insert(task)
        task.tags = [tag]
        try context.save()
        let counter = ChangeCounter()

        tags(counter).delete(tag)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TaskTag>()).isEmpty)
        #expect(task.tags.isEmpty)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(counter.count == 1)
    }
}
