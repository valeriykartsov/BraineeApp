//
//  MyTasksDocumentTests.swift
//  BraineeAppTests
//
//  Критичная логика JSON: нормализация и чтение старых файлов без потери данных.

import Foundation
import Testing
@testable import BraineeApp

struct MyTasksDocumentTests {

    @Test func дубликатыUUID_убираютсяПриНормализации() {
        // Две задачи с одним id — после normalize остаётся одна.
        let id = UUID()
        var document = MyTasksDocument(
            version: 2,
            lastSavedAt: nil,
            tags: [],
            groups: [],
            tasks: [
                makeTask(id: id, title: "Первая"),
                makeTask(id: id, title: "Дубликат")
            ]
        )
        document.normalizeRecords()
        #expect(document.tasks.count == 1)
        #expect(document.tasks[0].title == "Первая")
    }

    @Test func битаяСсылкаНаГруппу_обнуляется() {
        // groupID на несуществующую группу становится nil — задача не теряется.
        let orphanGroupID = UUID()
        var document = MyTasksDocument(
            version: 2,
            lastSavedAt: nil,
            tags: [],
            groups: [],
            tasks: [makeTask(id: UUID(), title: "Сирота", groupID: orphanGroupID)]
        )
        document.normalizeRecords()
        #expect(document.tasks.count == 1)
        #expect(document.tasks[0].groupID == nil)
    }

    @Test func битыеТеги_отфильтровываются() {
        // Ссылки на удалённые теги вычищаются, задача остаётся.
        let liveTag = UUID()
        let deadTag = UUID()
        var document = MyTasksDocument(
            version: 2,
            lastSavedAt: nil,
            tags: [TagRecord(id: liveTag, name: "Живой", createdAt: .now)],
            groups: [],
            tasks: [makeTask(id: UUID(), title: "С тегами", tagIDs: [liveTag, deadTag])]
        )
        document.normalizeRecords()
        #expect(document.tasks[0].tagIDs == [liveTag])
    }

    @Test func мягкоУдалённаяБезDeletedAt_получаетДату() {
        // У soft-deleted без deletedAt подставляется дата (createdAt).
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        var document = MyTasksDocument(
            version: 2,
            lastSavedAt: nil,
            tags: [],
            groups: [],
            tasks: [
                TaskRecord(
                    id: UUID(),
                    title: "Удалена",
                    isCompleted: false,
                    deadline: nil,
                    priorityRaw: 1,
                    categoryRaw: "career",
                    createdAt: created,
                    taskDetails: "",
                    sortOrder: 0,
                    groupID: nil,
                    tagIDs: [],
                    isDeleted: true,
                    deletedAt: nil
                )
            ]
        )
        document.normalizeRecords()
        #expect(document.tasks[0].deletedAt == created)
    }

    @Test func старыйJSONБезIsDeleted_читаетсяКакАктивная() throws {
        // Старый файл без полей soft delete не ломает загрузку.
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "Старая задача",
          "isCompleted": false,
          "priorityRaw": 1,
          "categoryRaw": "career",
          "createdAt": "2024-01-15T10:00:00Z",
          "taskDetails": "",
          "sortOrder": 0,
          "tagIDs": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(TaskRecord.self, from: data)

        #expect(record.title == "Старая задача")
        #expect(record.isDeleted == false)
        #expect(record.deletedAt == nil)
    }

    @Test func документТудаОбратноЧерезJSON_сохраняетЗадачи() throws {
        // Encode → decode не теряет задачи и флаги удаления.
        let taskID = UUID()
        let original = MyTasksDocument(
            version: 2,
            lastSavedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tags: [],
            groups: [],
            tasks: [
                TaskRecord(
                    id: taskID,
                    title: "Важная",
                    isCompleted: true,
                    deadline: nil,
                    priorityRaw: 3,
                    categoryRaw: "sport",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    taskDetails: "детали",
                    sortOrder: 2,
                    groupID: nil,
                    tagIDs: [],
                    isDeleted: true,
                    deletedAt: Date(timeIntervalSince1970: 1_700_000_100)
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MyTasksDocument.self, from: data)

        #expect(decoded.tasks.count == 1)
        #expect(decoded.tasks[0].id == taskID)
        #expect(decoded.tasks[0].title == "Важная")
        #expect(decoded.tasks[0].isDeleted == true)
        #expect(decoded.tasks[0].isCompleted == true)
        #expect(decoded.tasks[0].categoryRaw == "sport")
    }

    @Test func миграцияРазделов_всеСтановятсяTasks() {
        // Старые career/sport/mental и группы сливаются в единый раздел «Задачи».
        let groupID = UUID()
        var document = MyTasksDocument(
            version: 2,
            lastSavedAt: nil,
            tags: [],
            groups: [
                GroupRecord(id: groupID, name: "Папка", categoryRaw: "sport", sortOrder: 0, createdAt: .now)
            ],
            tasks: [
                TaskRecord(
                    id: UUID(),
                    title: "Карьера",
                    isCompleted: false,
                    deadline: nil,
                    priorityRaw: 1,
                    categoryRaw: "career",
                    createdAt: .now,
                    taskDetails: "",
                    sortOrder: 0,
                    groupID: groupID,
                    tagIDs: []
                ),
                TaskRecord(
                    id: UUID(),
                    title: "Ментальное",
                    isCompleted: false,
                    deadline: nil,
                    priorityRaw: 1,
                    categoryRaw: "mental",
                    createdAt: .now,
                    taskDetails: "",
                    sortOrder: 1,
                    groupID: nil,
                    tagIDs: []
                )
            ]
        )
        document.normalizeRecords()
        #expect(document.version == MyTasksDocument.currentVersion)
        #expect(document.habits.isEmpty)
        #expect(document.tasks.allSatisfy { $0.categoryRaw == TaskCategory.unifiedRaw })
        #expect(document.groups.allSatisfy { $0.categoryRaw == TaskCategory.unifiedRaw })
        #expect(document.tasks[0].groupID == groupID)
    }

    // MARK: - Helpers

    private func makeTask(
        id: UUID,
        title: String,
        groupID: UUID? = nil,
        tagIDs: [UUID] = []
    ) -> TaskRecord {
        TaskRecord(
            id: id,
            title: title,
            isCompleted: false,
            deadline: nil,
            priorityRaw: TaskPriority.medium.rawValue,
            categoryRaw: TaskCategory.unifiedRaw,
            createdAt: .now,
            taskDetails: "",
            sortOrder: 0,
            groupID: groupID,
            tagIDs: tagIDs
        )
    }
}
