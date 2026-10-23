//
//  TaskSubtaskDataTests.swift
//  BraineeAppTests
//
//  Данные SchemaV2 (D-39): длительность задачи и подзадачи в хранилище и JSON бэкапа.
//  Интерфейса пока нет — проверяются модель, удаление, экспорт/импорт и чтение старых файлов.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskSubtaskDataTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private func makeTask(subtaskIDs: [UUID] = [UUID(), UUID()], duration: Int? = 45) -> TaskItem {
        let task = TaskItem(
            title: "Задача",
            deadline: PersistenceFixtures.date(5_000),
            hasDeadlineTime: true,
            createdAt: PersistenceFixtures.date(0),
            durationMinutes: duration,
            subtasks: subtaskIDs.enumerated().map { index, id in
                TaskSubtask(uuid: id, title: "Шаг \(index + 1)", isDone: index == 0, sortOrder: index)
            }
        )
        context.insert(task)
        return task
    }

    // Длительность и подзадачи (текст, отметка, порядок) переживают экспорт в JSON и импорт в новое хранилище.
    @Test func экспортИмпорт_сохраняютДлительностьИПодзадачи() throws {
        let ids = [UUID(), UUID(), UUID()]
        let task = makeTask(subtaskIDs: ids)
        try context.save()

        let data = try PersistenceFixtures.encoder.encode(AppDataPersistence.exportTasks(from: context))
        let document = try PersistenceFixtures.decoder.decode(MyTasksDocument.self, from: data)
        let record = try #require(document.tasks.first)
        #expect(record.durationMinutes == 45)
        #expect(record.subtasks.map(\.id) == ids)
        #expect(record.subtasks.map(\.title) == ["Шаг 1", "Шаг 2", "Шаг 3"])
        #expect(record.subtasks.map(\.isDone) == [true, false, false])

        let other = try TestHelpers.makeContainer()
        AppDataPersistence.importTasks(document, into: other.mainContext)
        try other.mainContext.save()
        let restored = try #require(try other.mainContext.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(restored.uuid == task.uuid)
        #expect(restored.durationMinutes == 45)
        #expect(restored.sortedSubtasks.map(\.uuid) == ids)
        #expect(restored.sortedSubtasks.map(\.isDone) == [true, false, false])
        #expect(try other.mainContext.fetchCount(FetchDescriptor<TaskSubtask>()) == 3)
    }

    // Файл v9 (до D-39) читается: длительности нет, подзадач нет; задача без них пишется без новых ключей.
    @Test func файлV9_читаетсяБезДлительностиИПодзадач() throws {
        let json = """
        { "version": 9, "tasks": [{ "id": "\(UUID())", "title": "Старая", "createdAt": "2026-01-01T00:00:00Z" }] }
        """
        let document = try PersistenceFixtures.decoder.decode(MyTasksDocument.self, from: Data(json.utf8))
        let record = try #require(document.tasks.first)
        #expect(record.durationMinutes == nil)
        #expect(record.subtasks.isEmpty)

        let encoded = String(decoding: try PersistenceFixtures.encoder.encode(record), as: UTF8.self)
        #expect(!encoded.contains("durationMinutes"))
        #expect(!encoded.contains("subtasks"))
    }

    // Бэкап формата 1 (до D-39) по-прежнему восстанавливается.
    @Test func бэкапВерсии1_читается() throws {
        let json = """
        {
          "format": "braineeapp.backup", "version": 1, "exportedAt": "2026-10-20T10:00:00Z",
          "tasks": { "version": 9, "tasks": [{ "id": "\(UUID())", "title": "Старая", "createdAt": "2026-01-01T00:00:00Z" }] },
          "profile": { "version": 4, "displayName": "Алекс" }
        }
        """
        let backup = try BackupDocument.decode(from: Data(json.utf8))
        #expect(backup.version == 1)
        #expect(backup.tasks.tasks.first?.subtasks.isEmpty == true)
        #expect(BackupDocument.currentVersion == 2)
    }

    // Нормализация: длительность вне 1 мин…24 ч сбрасывается, повтор uuid подзадачи отбрасывается, порядок — по sortOrder.
    @Test func нормализация_чинитДлительностьИПодзадачи() {
        let shared = UUID()
        let first = UUID()
        var document = MyTasksDocument.empty
        document.tasks = [
            TaskRecord(
                id: UUID(), title: "A", isCompleted: false, deadline: nil, priorityRaw: 2, categoryRaw: "tasks",
                createdAt: PersistenceFixtures.date(0), taskDetails: "", sortOrder: 0, groupID: nil, tagIDs: [],
                durationMinutes: 0,
                subtasks: [
                    SubtaskRecord(id: shared, title: "второй", sortOrder: 5),
                    SubtaskRecord(id: first, title: "первый", sortOrder: 1),
                ]
            ),
            TaskRecord(
                id: UUID(), title: "B", isCompleted: false, deadline: nil, priorityRaw: 2, categoryRaw: "tasks",
                createdAt: PersistenceFixtures.date(0), taskDetails: "", sortOrder: 1, groupID: nil, tagIDs: [],
                durationMinutes: 24 * 60 + 1,
                subtasks: [SubtaskRecord(id: shared, title: "повтор")]
            ),
        ]

        document.normalizeRecords()

        #expect(document.tasks[0].durationMinutes == nil)
        #expect(document.tasks[1].durationMinutes == nil)
        #expect(document.tasks[0].subtasks.map(\.id) == [first, shared])
        #expect(document.tasks[1].subtasks.isEmpty)
    }

    // Корзина подзадачи не трогает; окончательное удаление задачи удаляет и их.
    @Test func окончательноеУдаление_удаляетПодзадачи() throws {
        let task = makeTask()
        let other = makeTask(subtaskIDs: [UUID()])
        try context.save()
        let service = TaskService(context: context, onChange: { _ in })

        task.isSoftDeleted = true
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TaskSubtask>()) == 3)

        service.permanentlyDelete([task])
        #expect(try context.fetchCount(FetchDescriptor<TaskSubtask>()) == 1)
        #expect(other.subtasks.count == 1)
    }

    // Восстановление из бэкапа убирает подзадачи, которых нет в файле, и обновляет оставшиеся по uuid.
    @Test func заменаИзДокумента_убираетЛишниеПодзадачи() throws {
        let keep = UUID()
        let task = makeTask(subtaskIDs: [keep, UUID()])
        try context.save()

        var document = AppDataPersistence.exportTasks(from: context)
        document.tasks[0].subtasks = [SubtaskRecord(id: keep, title: "Изменён", isDone: true, sortOrder: 0)]
        var profile: ProfileDocument? = nil
        _ = try StoreContents.replace(with: document, profile: &profile, in: context)
        try context.save()

        let subtasks = try context.fetch(FetchDescriptor<TaskSubtask>())
        #expect(subtasks.map(\.uuid) == [keep])
        #expect(subtasks.first?.title == "Изменён")
        #expect(task.subtasks.map(\.uuid) == [keep])
        try StoreContents.verify(tasks: document, profile: nil, in: container)
    }
}
