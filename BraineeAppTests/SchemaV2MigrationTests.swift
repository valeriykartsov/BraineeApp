//
//  SchemaV2MigrationTests.swift
//  BraineeAppTests
//
//  Переход хранилища с SchemaV1 на SchemaV2 (D-39): бэкап → копирование → проверка → маркер.
//  Образец `Fixtures/SchemaV1-demo.store` создан сборкой V1 (до заморозки) с демо-данными —
//  он проверяет, что замороженная SchemaV1 совпадает с настоящим хранилищем.
//  Всё происходит во временной папке; настоящие данные приложения не затрагиваются.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
final class SchemaV2MigrationTests {
    private let directory: URL
    private let defaults: UserDefaults
    private let suiteName = "SchemaV2MigrationTests-\(UUID().uuidString)"

    private var storeURL: URL { directory.appendingPathComponent("BraineeApp/BraineeApp.store") }
    private var backupsURL: URL { directory.appendingPathComponent("Backups", isDirectory: true) }
    private var backupURL: URL { backupsURL.appendingPathComponent("pre-schema-v2", isDirectory: true) }
    private var markerURL: URL { directory.appendingPathComponent("BraineeApp/schema-v2-migration.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppSchemaV2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("BraineeApp", isDirectory: true),
            withIntermediateDirectories: true
        )
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private var upgrade: SchemaUpgrade {
        SchemaUpgrade(storeURL: storeURL, backupDirectory: backupURL, markerURL: markerURL, defaults: defaults)
    }

    // MARK: - Хранилища V1

    private let taskID = UUID()
    private let plainTaskID = UUID()
    private let groupID = UUID()
    private let tagID = UUID()
    private let habitID = UUID()
    private let profileID = UUID()
    private let avatar = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])

    /// Даты с долями секунды: сверка при повторе не должна зависеть от округления в `backup.json`.
    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000.123456 + seconds)
    }

    /// Кладёт образец, созданный сборкой V1, на место хранилища.
    private func copyDemoFixture() throws {
        let bundle = Bundle(for: SchemaV2MigrationTests.self)
        let url = try #require(
            bundle.url(forResource: "SchemaV1-demo", withExtension: "store")
                ?? bundle.url(forResource: "SchemaV1-demo", withExtension: "store", subdirectory: "Fixtures"),
            "образец хранилища V1 не попал в тестовый бандл"
        )
        try FileManager.default.copyItem(at: url, to: storeURL)
    }

    /// Хранилище V1 со всеми полями: корзина без даты удаления, напоминания, папка, тег, аватар.
    private func writeRichV1Store() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let group = SchemaV1.TaskGroup(name: "Папка", sortOrder: 2, uuid: groupID, createdAt: date(100))
        let tag = SchemaV1.TaskTag(name: "дом", uuid: tagID, createdAt: date(200))
        let task = SchemaV1.TaskItem(
            title: "В корзине",
            isCompleted: true,
            deadline: date(5_000),
            hasDeadlineTime: true,
            reminderOffsetsRaw: [TaskReminderOffset.minutes15.rawValue],
            priorityRaw: TaskPriority.high.rawValue,
            statusRaw: TaskStatus.done.rawValue,
            createdAt: date(300),
            taskDetails: "описание",
            sortOrder: 4,
            uuid: taskID,
            isSoftDeleted: true,
            deletedAt: nil,
            updatedAt: date(800),
            completedAt: date(700),
            group: group,
            tags: [tag]
        )
        let plainTask = SchemaV1.TaskItem(title: "Без даты", createdAt: date(400), uuid: plainTaskID)
        let habit = SchemaV1.Habit(
            title: "Зарядка", sortOrder: 1, uuid: habitID, createdAt: date(500),
            completedDaysRaw: "[\"2026-10-18\",\"2026-10-20\"]"
        )
        let profile = SchemaV1.UserProfile(
            uuid: profileID, displayName: "Валера ", avatarData: avatar,
            age: 30, genderRaw: UserGender.male.rawValue, createdAt: date(10)
        )
        let models: [any PersistentModel] = [group, tag, task, plainTask, habit, profile]
        models.forEach { context.insert($0) }
        try context.save()
    }

    private func counts(in container: ModelContainer) throws -> [Int] {
        let context = ModelContext(container)
        return [
            try context.fetchCount(FetchDescriptor<TaskItem>()),
            try context.fetchCount(FetchDescriptor<TaskGroup>()),
            try context.fetchCount(FetchDescriptor<TaskTag>()),
            try context.fetchCount(FetchDescriptor<Habit>()),
            try context.fetchCount(FetchDescriptor<UserProfile>()),
            try context.fetchCount(FetchDescriptor<TaskSubtask>()),
        ]
    }

    private func readMarker() throws -> SchemaUpgrade.Marker {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SchemaUpgrade.Marker.self, from: Data(contentsOf: markerURL))
    }

    private func backupFiles() throws -> [String: Data] {
        let names = try FileManager.default.contentsOfDirectory(atPath: backupURL.path)
        return try Dictionary(uniqueKeysWithValues: names.map {
            ($0, try Data(contentsOf: backupURL.appendingPathComponent($0)))
        })
    }

    // MARK: - Тесты

    // Хранилище, созданное сборкой V1, открывается как V2 без потерь; рядом — бэкап и маркер.
    @Test func образецСборкиV1_переводитсяНаV2БезПотерь() throws {
        try copyDemoFixture()
        let original = try Data(contentsOf: storeURL)

        let container = try upgrade.openStore()
        try withExtendedLifetime(container) { () throws in
            #expect(try counts(in: container) == [9, 2, 2, 4, 1, 0])
            let tasks = try ModelContext(container).fetch(FetchDescriptor<TaskItem>())
            #expect(tasks.allSatisfy { $0.durationMinutes == nil && $0.subtasks.isEmpty })
            #expect(tasks.contains { $0.title == "Подготовить отчёт за квартал" && $0.group?.name == "Работа" })
        }

        let marker = try readMarker()
        #expect(marker.schemaVersion == "2.0.0")
        #expect(marker.backupFolder == "Backups/pre-schema-v2")
        #expect([marker.tasks, marker.groups, marker.tags, marker.habits] as [Int] == [9, 2, 2, 4])
        #expect(marker.hasProfile)

        let files = try backupFiles()
        #expect(files["BraineeApp.store"] == original)
        let backup = try BackupDocument.decode(from: try #require(files[SchemaUpgrade.backupFileName]))
        #expect(backup.version == 2)
        #expect(backup.tasks.tasks.count == 9)
        #expect(backup.tasks.habits.count == 4)
        #expect(backup.profile.displayName == "Алекс")
    }

    // Все поля хранилища V1 (корзина, напоминания, связи, аватар, доли секунды) переживают переход
    // и совпадают со снимком в бэкапе.
    @Test func всеПоляV1_совпадаютПослеПерехода() throws {
        try writeRichV1Store()

        let container = try upgrade.openStore()
        try withExtendedLifetime(container) { () throws in
            let context = ModelContext(container)
            #expect(try counts(in: container) == [2, 1, 1, 1, 1, 0])

            let task = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first { $0.uuid == taskID })
            #expect(task.title == "В корзине")
            #expect(task.status == .done)
            #expect(task.deadline == date(5_000))
            #expect(task.hasDeadlineTime)
            #expect(task.reminderOffsets == [.minutes15])
            #expect(task.priority == .high)
            #expect(task.isSoftDeleted)
            #expect(task.deletedAt == nil)
            #expect(task.updatedAt == date(800))
            #expect(task.completedAt == date(700))
            #expect(task.group?.uuid == groupID)
            #expect(task.tags.map(\.uuid) == [tagID])
            #expect(task.durationMinutes == nil)
            #expect(task.subtasks.isEmpty)

            let habit = try #require(try context.fetch(FetchDescriptor<Habit>()).first)
            #expect(habit.completedDayKeys == ["2026-10-18", "2026-10-20"])
            let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
            #expect(profile.displayName == "Валера ")
            #expect(profile.avatarData == avatar)
        }

        // В бэкапе перед переходом аватар сохраняется — это полный снимок.
        let backup = try BackupDocument.decode(from: try #require(try backupFiles()[SchemaUpgrade.backupFileName]))
        #expect(backup.profile.avatarBase64 == avatar.base64EncodedString())
        #expect(backup.tasks.tasks.first { $0.id == taskID }?.deletedAt != nil)
    }

    // Повторный запуск после перехода ничего не делает: второго бэкапа нет, бэкап и маркер не меняются, дублей нет.
    @Test func повторныйЗапуск_неСоздаётВторойБэкапИДублей() throws {
        try writeRichV1Store()
        try withExtendedLifetime(try upgrade.openStore()) {}
        let filesBefore = try backupFiles()
        let markerBefore = try Data(contentsOf: markerURL)

        let container = try upgrade.openStore()
        try withExtendedLifetime(container) { () throws in
            #expect(try counts(in: container) == [2, 1, 1, 1, 1, 0])
        }
        #expect(try backupFiles() == filesBefore)
        #expect(try Data(contentsOf: markerURL) == markerBefore)
        #expect(try FileManager.default.contentsOfDirectory(atPath: backupsURL.path) == ["pre-schema-v2"])
    }

    // Сбой после миграции, но до маркера: следующий запуск сверяет уже ставшее V2 хранилище
    // с сохранённым бэкапом (точные даты — из contents.json) и ставит маркер, не переписывая бэкап.
    @Test func сбойДоМаркера_повторСверяетсяССохранённымБэкапом() throws {
        try writeRichV1Store()
        try withExtendedLifetime(try upgrade.openStore()) {}
        let filesBefore = try backupFiles()
        try FileManager.default.removeItem(at: markerURL)

        let container = try upgrade.openStore()
        try withExtendedLifetime(container) { () throws in
            #expect(try counts(in: container) == [2, 1, 1, 1, 1, 0])
        }
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
        #expect(try backupFiles() == filesBefore)
    }

    // Если после сбоя данные в хранилище разошлись с бэкапом — ошибка и без маркера, а не «тихий» запуск.
    @Test func расхождениеСБэкапом_останавливаетПереход() throws {
        try writeRichV1Store()
        let first = try upgrade.openStore()
        let context = ModelContext(first)
        try context.fetch(FetchDescriptor<TaskItem>()).filter { $0.uuid == plainTaskID }.forEach { context.delete($0) }
        try context.save()
        try FileManager.default.removeItem(at: markerURL)

        #expect(throws: StoreContents.VerificationError.self) {
            _ = try self.upgrade.openStore()
        }
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
        withExtendedLifetime(first) {}
    }

    // Новая установка: хранилища нет — бэкап не нужен, маркер ставится сразу.
    @Test func новаяУстановка_маркерБезБэкапа() throws {
        let container = try upgrade.openStore()
        try withExtendedLifetime(container) { () throws in
            #expect(try counts(in: container) == [0, 0, 0, 0, 0, 0])
        }
        #expect(try readMarker().backupFolder == nil)
        #expect(!FileManager.default.fileExists(atPath: backupsURL.path))
    }

    // Остаток прерванного бэкапа (.partial) не считается бэкапом: собирается заново.
    @Test func незавершённыйБэкап_собираетсяЗаново() throws {
        try writeRichV1Store()
        let partial = backupsURL.appendingPathComponent("pre-schema-v2.partial", isDirectory: true)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try Data("обрывок".utf8).write(to: partial.appendingPathComponent("backup.json"))

        try withExtendedLifetime(try upgrade.openStore()) {}

        #expect(!FileManager.default.fileExists(atPath: partial.path))
        let backup = try BackupDocument.decode(from: try #require(try backupFiles()[SchemaUpgrade.backupFileName]))
        #expect(backup.tasks.tasks.count == 2)
    }

    // Папка бэкапа есть, а снимка в ней нет — переход останавливается; папка не удаляется, маркера нет.
    @Test func папкаБэкапаБезСнимка_переходОстанавливается() throws {
        try writeRichV1Store()
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)

        #expect(throws: SchemaUpgrade.UpgradeError.self) {
            _ = try self.upgrade.openStore()
        }
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }
}
