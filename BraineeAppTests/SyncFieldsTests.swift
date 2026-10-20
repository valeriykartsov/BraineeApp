//
//  SyncFieldsTests.swift
//  BraineeAppTests
//
//  Поля для синхронизации и отчётов (roadmap DOM-3): updatedAt, completedAt, uuid профиля,
//  обратная совместимость JSON v8 → v9 и profile v3 → v4.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct SyncFieldsTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    /// Фиксированное «сейчас» для сервисов и «старая» дата для проверки, что updatedAt изменился.
    private let fixedNow = PersistenceFixtures.date(9_000)
    private let oldDate = PersistenceFixtures.date(0)

    // MARK: - Обратная совместимость JSON

    // Файл v8 без новых полей: updatedAt = createdAt, completedAt = nil (D-03), версия становится 9.
    @Test func файлV8_новыеПоляПолучаютЗначенияПоУмолчанию() throws {
        let json = """
        {
          "version": 8,
          "tags": [{ "id": "\(UUID())", "name": "тег", "createdAt": "2026-01-01T00:00:00Z" }],
          "groups": [{ "id": "\(UUID())", "name": "Папка", "sortOrder": 0, "createdAt": "2026-01-02T00:00:00Z" }],
          "tasks": [{
            "id": "\(UUID())", "title": "Готовая", "isCompleted": true, "statusRaw": "done",
            "createdAt": "2026-01-03T00:00:00Z", "priorityRaw": 1, "categoryRaw": "tasks",
            "taskDetails": "", "sortOrder": 0, "tagIDs": [], "isDeleted": false,
            "hasDeadlineTime": false, "reminderOffsetsRaw": []
          }],
          "habits": [{ "id": "\(UUID())", "title": "Спорт", "sortOrder": 0, "createdAt": "2026-01-04T00:00:00Z" }]
        }
        """
        var document = try PersistenceFixtures.decoder.decode(MyTasksDocument.self, from: Data(json.utf8))
        document.normalizeRecords()

        #expect(document.version == 9)
        #expect(document.tags[0].updatedAt == document.tags[0].createdAt)
        #expect(document.groups[0].updatedAt == document.groups[0].createdAt)
        #expect(document.tasks[0].updatedAt == document.tasks[0].createdAt)
        #expect(document.tasks[0].completedAt == nil)
        #expect(document.habits[0].updatedAt == document.habits[0].createdAt)
    }

    // Нормализация: дата закрытия у невыполненной задачи сбрасывается.
    @Test func нормализация_completedAtТолькоУВыполненных() {
        var document = MyTasksDocument(
            version: 9,
            lastSavedAt: nil,
            tags: [],
            groups: [],
            tasks: [
                TaskRecord(
                    id: UUID(), title: "Новая", isCompleted: false, deadline: nil,
                    priorityRaw: 1, categoryRaw: TaskCategory.unifiedRaw,
                    statusRaw: TaskStatus.new.rawValue, createdAt: oldDate,
                    taskDetails: "", sortOrder: 0, groupID: nil, tagIDs: [],
                    completedAt: fixedNow
                )
            ]
        )

        document.normalizeRecords()

        #expect(document.tasks[0].completedAt == nil)
    }

    // profile.json v3 без id: id = nil; импорт создаёт uuid, экспорт его сохраняет.
    @Test func профильБезId_импортСоздаётUuidЭкспортСохраняет() throws {
        let json = """
        { "version": 3, "displayName": "Валера", "genderRaw": "unspecified",
          "appThemeRaw": "system", "accentPaletteRaw": "orange", "createdAt": "2026-01-01T00:00:00Z" }
        """
        let document = try PersistenceFixtures.decoder.decode(ProfileDocument.self, from: Data(json.utf8))
        #expect(document.id == nil)
        let context = container.mainContext

        AppDataPersistence.importProfile(document, into: context)
        try context.save()
        let model = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        let exported = AppDataPersistence.exportProfile(from: context)

        #expect(exported.id == model.uuid)
        #expect(exported.version == ProfileDocument.currentVersion)
    }

    // MARK: - completedAt в модели

    // «Готово» ставит дату закрытия, повторное «Готово» её не сдвигает, выход из «Готово» сбрасывает.
    @Test func статусГотово_ставитИСбрасываетДатуЗакрытия() throws {
        let task = TaskItem(title: "Задача")
        container.mainContext.insert(task)
        #expect(task.completedAt == nil)

        task.status = .done
        let closedAt = try #require(task.completedAt)
        task.status = .done
        #expect(task.completedAt == closedAt)

        task.status = .inProgress
        #expect(task.completedAt == nil)
        task.applyCompletionToggle()
        #expect(task.completedAt != nil)
        task.applyCompletionToggle()
        #expect(task.completedAt == nil)
    }

    // Импорт: невыполненная задача не может получить дату закрытия.
    @Test func импортНевыполненной_безДатыЗакрытия() {
        let task = TaskItem(title: "Новая", status: .new, completedAt: fixedNow)

        #expect(task.completedAt == nil)
    }

    // MARK: - updatedAt в сервисах

    private func ignore(_: ModelContext) {}

    // TaskService: каждое изменение задачи ставит updatedAt = now.
    @Test func задачи_каждаяОперацияОбновляетUpdatedAt() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Папка")
        context.insert(group)
        let task = TaskItem(title: "Задача", createdAt: oldDate)
        context.insert(task)
        let service = TaskService(context: context, onChange: ignore, now: { fixedNow })
        let form = TaskFormData(
            title: "Новое", deadline: nil, hasDeadlineTime: false, reminderOffsets: [],
            priority: .high, status: .new, taskDetails: "", selectedTags: []
        )

        let operations: [(String, () -> Void)] = [
            ("update", { service.update(task, from: form) }),
            ("toggle", { service.toggleCompletion(task) }),
            ("setStatus", { service.setStatus(task, .inProgress) }),
            ("move", { service.move(task, to: group) }),
            ("softDelete", { service.softDelete(task) }),
            ("restore", { service.restore(task) })
        ]
        for (name, operation) in operations {
            task.updatedAt = oldDate
            operation()
            #expect(task.updatedAt == fixedNow, "операция \(name)")
        }

        let created = service.create(from: form)
        #expect(created.createdAt == fixedNow)
        #expect(created.updatedAt == fixedNow)
    }

    // Удаление группы меняет группу у задач — их updatedAt обновляется; задачи из других групп не трогаются.
    @Test func удалениеГруппы_обновляетUpdatedAtЗатронутыхЗадач() throws {
        let context = container.mainContext
        let group = TaskGroup(name: "Удаляемая")
        let other = TaskGroup(name: "Другая")
        context.insert(group)
        context.insert(other)
        let inGroup = TaskItem(title: "В группе", createdAt: oldDate, group: group)
        let inOther = TaskItem(title: "В другой", createdAt: oldDate, group: other)
        context.insert(inGroup)
        context.insert(inOther)
        let service = GroupService(context: context, onChange: ignore, now: { fixedNow })

        service.rename(other, to: "Переименована")
        service.delete(group)

        #expect(inGroup.updatedAt == fixedNow)
        #expect(inOther.updatedAt == oldDate)
        #expect(other.updatedAt == fixedNow)
    }

    // Удаление тега меняет теги задач — их updatedAt обновляется.
    @Test func удалениеТега_обновляетUpdatedAtЗадачСТегом() throws {
        let context = container.mainContext
        let tag = TaskTag(name: "тег", createdAt: oldDate)
        context.insert(tag)
        let tagged = TaskItem(title: "С тегом", createdAt: oldDate)
        let plain = TaskItem(title: "Без тега", createdAt: oldDate)
        context.insert(tagged)
        context.insert(plain)
        tagged.tags = [tag]
        try context.save()
        let service = TagService(context: context, onChange: ignore, now: { fixedNow })

        service.rename(tag, to: "новый")
        #expect(tag.updatedAt == fixedNow)
        service.delete(tag)

        #expect(tagged.updatedAt == fixedNow)
        #expect(plain.updatedAt == oldDate)
    }

    // Привычки: переименование и отметка обновляют updatedAt; перестановка — только у сдвинутых.
    @Test func привычки_updatedAtТолькоУИзменённых() throws {
        let context = container.mainContext
        let first = Habit(title: "A", sortOrder: 0, createdAt: oldDate)
        let second = Habit(title: "B", sortOrder: 1, createdAt: oldDate)
        let third = Habit(title: "C", sortOrder: 2, createdAt: oldDate)
        for habit in [first, second, third] { context.insert(habit) }
        let service = HabitService(context: context, onChange: ignore, now: { fixedNow })

        service.move(second.uuid, onto: third.uuid)
        #expect(first.updatedAt == oldDate)
        #expect(second.updatedAt == fixedNow)
        #expect(third.updatedAt == fixedNow)

        first.updatedAt = oldDate
        service.rename(first, to: "AA")
        #expect(first.updatedAt == fixedNow)

        first.updatedAt = oldDate
        service.toggle(first, on: .now)
        #expect(first.updatedAt == fixedNow)
    }
}
