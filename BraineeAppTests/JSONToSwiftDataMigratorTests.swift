//
//  JSONToSwiftDataMigratorTests.swift
//  BraineeAppTests
//
//  Мигратор JSON → SwiftData (roadmap SD-2): бэкап, upsert по uuid, проверка, маркер, отчёт.
//  Всё во временных папках и отдельном Keychain service — настоящие данные не затрагиваются.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
final class JSONToSwiftDataMigratorTests {
    /// Исходные JSON и Keychain-копии.
    private let source: TemporaryDataStore
    /// Хранилище SwiftData, бэкапы и маркер.
    private let directory: URL
    private let container: ModelContainer
    private let fixedNow = PersistenceFixtures.date(10_000)

    init() throws {
        source = try TemporaryDataStore()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppMigratorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainerFactory.make(.persistent(url: directory.appendingPathComponent("BraineeApp.store")))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private var storeURL: URL { directory.appendingPathComponent("BraineeApp.store") }
    private var backupsDirectory: URL { directory.appendingPathComponent("Backups", isDirectory: true) }
    private var markerURL: URL { directory.appendingPathComponent("BraineeApp/swiftdata-migration.json") }

    private func makeMigrator(checkpoint: @escaping (JSONToSwiftDataMigrator.Stage) throws -> Void = { _ in }) -> JSONToSwiftDataMigrator {
        JSONToSwiftDataMigrator(
            locations: .init(source: source.location, backupsDirectory: backupsDirectory, markerURL: markerURL),
            now: { [fixedNow] in fixedNow },
            checkpoint: checkpoint
        )
    }

    private func migratedReport(_ outcome: JSONToSwiftDataMigrator.Outcome) throws -> MigrationReport {
        guard case .migrated(let report) = outcome else {
            Issue.record("Ожидался перенос, получено \(outcome)")
            throw CancellationError()
        }
        return report
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<T>())
    }

    private func backupFolders() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backupsDirectory.path)) ?? []
        return names.sorted().map { backupsDirectory.appendingPathComponent($0) }
    }

    private struct InjectedFailure: Error {}

    private static func task(_ id: UUID = UUID(), title: String, groupID: UUID? = nil, tagIDs: [UUID] = []) -> TaskRecord {
        TaskRecord(
            id: id, title: title, isCompleted: false, deadline: nil,
            priorityRaw: TaskPriority.medium.rawValue, categoryRaw: TaskCategory.unifiedRaw,
            createdAt: PersistenceFixtures.date(5), taskDetails: "", sortOrder: 0,
            groupID: groupID, tagIDs: tagIDs
        )
    }

    private static func habit(_ id: UUID = UUID(), title: String, sortOrder: Int) -> HabitRecord {
        HabitRecord(id: id, title: title, sortOrder: sortOrder, createdAt: PersistenceFixtures.date(6), completedDays: [])
    }

    // MARK: - Перенос

    // Нет ни файлов, ни Keychain: перенос успешен, хранилище пустое, маркер поставлен.
    @Test func пустыеДанные_маркерСтавитсяХранилищеПустое() throws {
        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.source == MigrationReport.Counts())
        #expect(report.migrated == MigrationReport.Counts())
        #expect(report.droppedRecords == 0)
        #expect(try count(TaskItem.self) == 0)
        #expect(try count(UserProfile.self) == 0)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }

    // Обычный набор: все сущности и поля в хранилище совпадают с JSON, профиль перенесён.
    @Test func обычныйНабор_всеЗаписиПереносятсяБезПотерь() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(original)
        let profile = PersistenceFixtures.profileDocument()
        try PersistenceFixtures.encoder.encode(profile).write(to: source.profileFileURL)

        let report = try migratedReport(makeMigrator().run(into: container))

        let context = ModelContext(container)
        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: context), original)
        let stored = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(stored.uuid == PersistenceFixtures.profileID)
        #expect(stored.displayName == profile.displayName)
        #expect(stored.avatarData == Data([0x01, 0x02, 0x03, 0xFF]))
        #expect(try count(UserProfile.self) == 1)

        let expectedCounts = MigrationReport.Counts(tasks: 3, groups: 1, tags: 2, habits: 1, profiles: 1)
        #expect(report.source == expectedCounts)
        #expect(report.migrated == expectedCounts)
        #expect(report.droppedRecords == 0)
        #expect(report.migratedAt == fixedNow)
    }

    // Дубликаты uuid в JSON: остаётся первая запись, отчёт считает отброшенные.
    @Test func дубликатыUUID_отбрасываютсяИПопадаютВОтчёт() throws {
        let taskID = UUID()
        let tagID = UUID()
        let habitID = UUID()
        try source.writeTasksFile(MyTasksDocument(
            version: 9, lastSavedAt: nil,
            tags: [TagRecord(id: tagID, name: "тег", createdAt: PersistenceFixtures.date(1)),
                   TagRecord(id: tagID, name: "тег-дубль", createdAt: PersistenceFixtures.date(1))],
            groups: [],
            tasks: [Self.task(taskID, title: "Первая"), Self.task(taskID, title: "Дубль"), Self.task(title: "Другая")],
            habits: [Self.habit(habitID, title: "Спорт", sortOrder: 0), Self.habit(habitID, title: "Спорт-дубль", sortOrder: 1)]
        ))

        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.droppedDuplicates == MigrationReport.Counts(tasks: 1, groups: 0, tags: 1, habits: 1))
        #expect(report.droppedRecords == 3)
        #expect(report.migrated.tasks == 2)
        let tasks = try ModelContext(container).fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.first { $0.uuid == taskID }?.title == "Первая")
        #expect(try count(TaskTag.self) == 1)
        #expect(try count(Habit.self) == 1)
    }

    // Висячие ссылки на группу и теги убираются, задачи сохраняются; отчёт считает ссылки.
    @Test func висячиеСсылки_убираютсяЗадачиСохраняются() throws {
        let liveTag = UUID()
        try source.writeTasksFile(MyTasksDocument(
            version: 9, lastSavedAt: nil,
            tags: [TagRecord(id: liveTag, name: "живой", createdAt: PersistenceFixtures.date(1))],
            groups: [],
            tasks: [
                Self.task(title: "Без папки", groupID: UUID()),
                Self.task(title: "С тегами", tagIDs: [liveTag, UUID(), UUID()]),
            ]
        ))

        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.clearedGroupReferences == 1)
        #expect(report.removedTagReferences == 2)
        #expect(report.droppedRecords == 0)
        let tasks = try ModelContext(container).fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 2)
        #expect(tasks.allSatisfy { $0.group == nil })
        #expect(tasks.first { $0.title == "С тегами" }?.tags.map(\.uuid) == [liveTag])
    }

    // Больше 7 привычек и пустые названия: лишние отбрасываются по sortOrder, отчёт считает оба случая.
    @Test func большеСемиПривычек_лишниеОтбрасываютсяИПопадаютВОтчёт() throws {
        var habits = (0..<9).map { Self.habit(title: "Привычка \($0)", sortOrder: $0) }
        habits[2].title = "   "
        try source.writeTasksFile(MyTasksDocument(version: 9, lastSavedAt: nil, tags: [], groups: [], tasks: [], habits: habits))

        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.droppedHabitsOverLimit == 2)
        #expect(report.droppedHabitsWithEmptyTitle == 1)
        #expect(report.migrated.habits == 6)
        let titles = Set(try ModelContext(container).fetch(FetchDescriptor<Habit>()).map(\.title))
        #expect(titles == Set([0, 1, 3, 4, 5, 6].map { "Привычка \($0)" }))
    }

    // После переустановки файла нет, данные только в Keychain — переносятся из Keychain.
    @Test func толькоKeychain_данныеПереносятся() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksKeychain(original)
        try source.writeProfileKeychain(PersistenceFixtures.profileDocument())

        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.migrated.tasks == original.tasks.count)
        #expect(report.migrated.profiles == 1)
        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: ModelContext(container)), original)
    }

    // MARK: - Повторный запуск и сбои

    // Повторный запуск после успеха ничего не делает: нет дублей, нового бэкапа, отчёт из маркера.
    @Test func повторныйЗапуск_ничегоНеДелаетИНеСоздаётДублей() throws {
        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        let first = try migratedReport(makeMigrator().run(into: container))

        let reopened = try ModelContainerFactory.make(.persistent(url: storeURL))
        let second = try makeMigrator().run(into: reopened)

        #expect(second == .alreadyCompleted(first))
        #expect(try ModelContext(reopened).fetchCount(FetchDescriptor<TaskItem>()) == 3)
        #expect(backupFolders().count == 1)
    }

    // Сбой после записи в хранилище: маркер не ставится; следующий запуск переносит заново без дублей.
    @Test func сбойПослеЗаписи_маркерНеСтавитсяПовторБезДублей() throws {
        let original = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(original)
        try source.writeProfileKeychain(PersistenceFixtures.profileDocument())

        #expect(throws: InjectedFailure.self) {
            try self.makeMigrator { stage in
                if stage == .saved { throw InjectedFailure() }
            }.run(into: self.container)
        }
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
        #expect(try count(TaskItem.self) == original.tasks.count)

        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.removedStaleRecords == 0)
        #expect(try count(TaskItem.self) == original.tasks.count)
        #expect(try count(TaskTag.self) == original.tags.count)
        #expect(try count(UserProfile.self) == 1)
        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: ModelContext(container)), original)
    }

    // Между прерванной попыткой и повтором задачу удалили в JSON: в хранилище её тоже не остаётся.
    @Test func повторПослеСбоя_удаляетЗаписиКоторыхНетВJSON() throws {
        var document = PersistenceFixtures.fullTasksDocument()
        try source.writeTasksFile(document)
        _ = try? makeMigrator { stage in
            if stage == .saved { throw InjectedFailure() }
        }.run(into: container)

        let removedID = document.tasks.removeLast().id
        try source.writeTasksFile(document)
        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(report.removedStaleRecords == 1)
        let ids = try ModelContext(container).fetch(FetchDescriptor<TaskItem>()).map(\.uuid)
        #expect(!ids.contains(removedID))
        #expect(ids.count == document.tasks.count)
    }

    // Старый profile.json без id: повтор после сбоя не создаёт второй профиль.
    @Test func профильБезID_повторПослеСбояНеСоздаётДубль() throws {
        var profile = PersistenceFixtures.profileDocument()
        profile.id = nil
        try PersistenceFixtures.encoder.encode(profile).write(to: source.profileFileURL)

        _ = try? makeMigrator { stage in
            if stage == .saved { throw InjectedFailure() }
        }.run(into: container)
        let firstID = try #require(try ModelContext(container).fetch(FetchDescriptor<UserProfile>()).first?.uuid)

        try makeMigrator().run(into: container)

        let profiles = try ModelContext(container).fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.map(\.uuid) == [firstID])
    }

    // Битый файл без Keychain-копии: ошибка, ни бэкапа, ни маркера, файл не тронут.
    @Test func битыйФайлБезKeychain_ошибкаИФайлНеТронут() throws {
        let garbage = Data("{ не json".utf8)
        try garbage.write(to: source.tasksFileURL)

        #expect(throws: AppDataStoreError.self) {
            try self.makeMigrator().run(into: self.container)
        }
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
        #expect(backupFolders().isEmpty)
        #expect(try Data(contentsOf: source.tasksFileURL) == garbage)
    }

    // Бэкап не создаётся (на месте папки — файл): перенос не начинается, маркера нет.
    @Test func ошибкаБэкапа_переносНеНачинается() throws {
        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        try Data().write(to: backupsDirectory)

        #expect(throws: MigrationError.self) {
            try self.makeMigrator().run(into: self.container)
        }
        #expect(try count(TaskItem.self) == 0)
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }

    // MARK: - Бэкап и исходные данные

    // Бэкап содержит точные копии файлов и Keychain; исходные файлы после переноса не меняются.
    @Test func бэкап_точныеКопииИсходникиНеМеняются() throws {
        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        try PersistenceFixtures.encoder.encode(PersistenceFixtures.profileDocument()).write(to: source.profileFileURL)
        try source.writeTasksKeychain(PersistenceFixtures.fullTasksDocument())
        let tasksBefore = try Data(contentsOf: source.tasksFileURL)
        let profileBefore = try Data(contentsOf: source.profileFileURL)
        let keychainBefore = try #require(source.keychainData(account: AppDataStore.tasksFileName))

        let report = try migratedReport(makeMigrator().run(into: container))

        let folder = try #require(backupFolders().first)
        #expect(folder.lastPathComponent == report.backupFolderName)
        #expect(report.backupFolderName.hasPrefix("pre-swiftdata-"))
        #expect(try Data(contentsOf: folder.appendingPathComponent(AppDataStore.tasksFileName)) == tasksBefore)
        #expect(try Data(contentsOf: folder.appendingPathComponent(AppDataStore.profileFileName)) == profileBefore)
        #expect(try Data(contentsOf: folder.appendingPathComponent("keychain-\(AppDataStore.tasksFileName)")) == keychainBefore)

        #expect(try Data(contentsOf: source.tasksFileURL) == tasksBefore)
        #expect(try Data(contentsOf: source.profileFileURL) == profileBefore)
        #expect(source.keychainData(account: AppDataStore.tasksFileName) == keychainBefore)
    }

    // Маркер читается обратно и содержит тот же отчёт.
    @Test func маркер_содержитОтчёт() throws {
        try source.writeTasksFile(PersistenceFixtures.fullTasksDocument())
        let report = try migratedReport(makeMigrator().run(into: container))

        #expect(makeMigrator().isCompleted)
        #expect(try makeMigrator().run(into: container) == .alreadyCompleted(report))
    }
}
