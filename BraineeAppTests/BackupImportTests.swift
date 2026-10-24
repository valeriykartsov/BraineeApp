//
//  BackupImportTests.swift
//  BraineeAppTests
//
//  Восстановление из резервной копии (roadmap SD-5): полный цикл экспорт → изменения → восстановление,
//  аватар и оформление, старые форматы, невалидные файлы. Всё во временной папке и отдельных UserDefaults.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
@Suite(.serialized)
final class BackupImportTests {
    private let directory: URL
    private let container: ModelContainer
    private let defaultsSuite = "BraineeAppBackupImportTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let original = PersistenceFixtures.fullTasksDocument()
    private let fixedNow = PersistenceFixtures.date(50_000)
    private let avatar = Data([0x89, 0x50, 0x4E, 0x47])

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BraineeAppBackupImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainerFactory.make(.persistent(url: directory.appendingPathComponent("BraineeApp.store")))
        defaults = try #require(UserDefaults(suiteName: defaultsSuite))

        let context = container.mainContext
        AppDataPersistence.importTasks(original, into: context)
        AppDataPersistence.importProfile(PersistenceFixtures.profileDocument(), into: context)
        try context.save()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private var safetyDirectory: URL { directory.appendingPathComponent("pre-restore", isDirectory: true) }

    private var restorer: BackupRestore {
        BackupRestore(safetyBackupDirectory: safetyDirectory, defaults: defaults, now: { [fixedNow] in fixedNow })
    }

    private func safetyFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: safetyDirectory.path)) ?? []
        return names.sorted().map { safetyDirectory.appendingPathComponent($0) }
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - Полный цикл

    // Экспорт → удалить задачу и создать новую → восстановление: данные идентичны бэкапу,
    // а состояние до восстановления сохранено в отдельный файл.
    @Test func полныйЦикл_данныеИдентичныБэкапу() throws {
        let context = container.mainContext
        let backupData = try BackupDocument.make(from: context, now: fixedNow).encoded()

        let removed = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        context.delete(removed)
        context.insert(TaskItem(title: "Создана после бэкапа"))
        try context.save()

        let safetyURL = try restorer.restore(BackupRestore.preview(backupData), into: container)

        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: context), original)
        #expect(try count(UserProfile.self) == 1)

        #expect(safetyFiles() == [safetyURL])
        let safety = try BackupDocument.decode(from: Data(contentsOf: safetyURL))
        #expect(safety.tasks.tasks.count == original.tasks.count)
        #expect(safety.tasks.tasks.contains { $0.title == "Создана после бэкапа" })
        #expect(!safety.tasks.tasks.contains { $0.id == removed.uuid })
    }

    // Главный контекст (как в UI) после восстановления видит новые значения, а не закэшированные старые.
    @Test func главныйКонтекст_видитВосстановленныеЗначения() throws {
        let context = container.mainContext
        let backupData = try BackupDocument.make(from: context, now: fixedNow).encoded()
        let task = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first { $0.title == "Задача со всеми полями" })
        let taskID = task.uuid
        task.title = "Переименована после бэкапа"
        try context.save()

        try restorer.restore(BackupRestore.preview(backupData), into: container)

        let fetched = try context.fetch(FetchDescriptor<TaskItem>()).first { $0.uuid == taskID }
        #expect(fetched?.title == "Задача со всеми полями")
    }

    // MARK: - Профиль и оформление

    // Аватара в бэкапе нет (D-16) — текущий аватар остаётся; имя, возраст и пол — из бэкапа.
    @Test func аватар_остаётсяТекущим() throws {
        let context = container.mainContext
        let backupData = try BackupDocument.make(from: context, now: fixedNow).encoded()
        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        profile.avatarData = avatar
        profile.displayName = "Другое имя"
        try context.save()

        try restorer.restore(BackupRestore.preview(backupData), into: container)

        let restored = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(restored.avatarData == avatar)
        #expect(restored.displayName == PersistenceFixtures.profileDocument().displayName)
        #expect(restored.uuid == PersistenceFixtures.profileID)
        #expect(try count(UserProfile.self) == 1)
    }

    // Тема и акцент из бэкапа записываются в UserDefaults.
    @Test func темаИАкцент_изБэкапа() throws {
        var document = BackupDocument.make(from: container.mainContext, now: fixedNow)
        document.profile.appThemeRaw = AppTheme.dark.rawValue
        document.profile.accentPaletteRaw = AccentPalette.blue.rawValue

        try restorer.restore(BackupRestore.preview(document.encoded()), into: container)

        #expect(defaults.string(forKey: "appTheme") == AppTheme.dark.rawValue)
        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.blue.rawValue)
    }

    // Статус (D-45) попадает в экспорт и из бэкапа записывается в UserDefaults; пустой (старый бэкап) — очищается.
    @Test func статус_изБэкапа() throws {
        // В экспорт (ручной и автобэкап) статус попадает из UserDefaults.
        defaults.set("фокус на проекте", forKey: ProfileStatus.storageKey)
        #expect(AppDataPersistence.exportProfile(from: container.mainContext, defaults: defaults).status == "фокус на проекте")

        var document = BackupDocument.make(from: container.mainContext, now: fixedNow)
        document.profile.status = "в отпуске"
        try restorer.restore(BackupRestore.preview(document.encoded()), into: container)
        #expect(defaults.string(forKey: ProfileStatus.storageKey) == "в отпуске")

        document.profile.status = ""
        try restorer.restore(BackupRestore.preview(document.encoded()), into: container)
        #expect(defaults.object(forKey: ProfileStatus.storageKey) == nil)
    }

    // MARK: - Форматы

    // Бэкап с задачами формата v8 (без updatedAt/completedAt) восстанавливается: updatedAt = createdAt.
    @Test func бэкапV8_восстанавливаетсяСоЗначениямиПоУмолчанию() throws {
        let taskID = UUID()
        let json = """
        {
          "format": "braineeapp.backup", "version": 1, "exportedAt": "2026-10-01T10:00:00Z",
          "tasks": {
            "version": 8,
            "tags": [], "groups": [], "habits": [],
            "tasks": [{
              "id": "\(taskID)", "title": "Старый формат", "isCompleted": true, "statusRaw": "done",
              "createdAt": "2026-01-03T00:00:00Z", "priorityRaw": 1, "categoryRaw": "tasks",
              "taskDetails": "", "sortOrder": 0, "tagIDs": [], "isDeleted": false,
              "hasDeadlineTime": false, "reminderOffsetsRaw": []
            }]
          },
          "profile": {
            "version": 3, "displayName": "Старый профиль", "genderRaw": "unspecified",
            "appThemeRaw": "system", "accentPaletteRaw": "orange", "createdAt": "2026-01-01T00:00:00Z"
          }
        }
        """

        try restorer.restore(BackupRestore.preview(Data(json.utf8)), into: container)

        let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.map(\.uuid) == [taskID])
        let task = try #require(tasks.first)
        #expect(task.updatedAt == task.createdAt)
        #expect(task.completedAt == nil)
        #expect(task.status == .done)
        #expect(try count(TaskGroup.self) == 0)
        #expect(try count(Habit.self) == 0)
        // Профиль без id в бэкапе получает uuid текущего профиля — второго профиля не появляется.
        let profiles = try container.mainContext.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.map(\.uuid) == [PersistenceFixtures.profileID])
        #expect(profiles.first?.displayName == "Старый профиль")
    }

    // MARK: - Невалидные файлы

    // Не бэкап, более новая версия формата и битый JSON отклоняются на предпросмотре — данные не меняются.
    @Test(arguments: [
        #"{ "version": 9, "tasks": [] }"#,
        #"{ "format": "braineeapp.backup", "version": 2, "exportedAt": "2026-10-01T10:00:00Z" }"#,
        "{ не json",
        "",
    ])
    func невалидныйФайл_данныеНеМеняются(_ content: String) throws {
        let before = AppDataPersistence.exportTasks(from: container.mainContext)

        #expect(throws: (any Error).self) {
            try BackupRestore.preview(Data(content.utf8))
        }

        RecordAssert.sameContent(AppDataPersistence.exportTasks(from: container.mainContext), before)
        #expect(safetyFiles().isEmpty)
    }

    // Предпросмотр показывает дату и количества из файла.
    @Test func предпросмотр_датаИСводка() throws {
        let document = BackupDocument.make(from: container.mainContext, now: fixedNow)
        let preview = try BackupRestore.preview(document.encoded())

        #expect(preview.exportedAt == fixedNow)
        #expect(preview.summary == document.summary)
    }
}
