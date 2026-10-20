//
//  BackupDocumentTests.swift
//  BraineeAppTests
//
//  Ручной бэкап (roadmap BASE-2): в файл попадают все данные, и он читается обратно без потерь.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct BackupDocumentTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    // Бэкап из SwiftData → байты → чтение: все сущности и поля совпадают с исходными, включая корзину.
    @Test func бэкапИзКонтекста_читаетсяОбратноБезПотерь() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()
        AppDataPersistence.importTasks(original, into: context)
        AppDataPersistence.importProfile(PersistenceFixtures.profileDocument(), into: context)
        try context.save()

        let data = try BackupDocument.make(from: context, now: PersistenceFixtures.date(5_000)).encoded()
        let restored = try BackupDocument.decode(from: data)

        RecordAssert.sameContent(restored.tasks, original)
        #expect(restored.format == BackupDocument.formatID)
        #expect(restored.version == BackupDocument.currentVersion)
        #expect(restored.exportedAt == PersistenceFixtures.date(5_000))
        let profile = PersistenceFixtures.profileDocument()
        #expect(restored.profile.displayName == profile.displayName)
        #expect(restored.profile.age == profile.age)
        #expect(restored.profile.genderRaw == profile.genderRaw)
        #expect(restored.profile.createdAt == profile.createdAt)
    }

    // Аватар не попадает в бэкап (D-16), даже если он есть в профиле, — файл не утяжеляется.
    @Test func аватар_неПопадаетВБэкап() throws {
        let context = container.mainContext
        AppDataPersistence.importProfile(PersistenceFixtures.profileDocument(), into: context)
        try context.save()
        let profileInStore = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profileInStore.avatarData != nil)

        let data = try BackupDocument.make(from: context).encoded()
        let restored = try BackupDocument.decode(from: data)

        #expect(restored.profile.avatarBase64 == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains("avatarBase64"))
        // Экспорт не трогает сам профиль в приложении.
        #expect(profileInStore.avatarData != nil)
    }

    // Вложенный tasks — обычный MyTasksDocument: его можно извлечь и прочитать как mytasks.json.
    @Test func задачиВБэкапе_читаютсяКакMyTasksDocument() throws {
        let context = container.mainContext
        let original = PersistenceFixtures.fullTasksDocument()
        AppDataPersistence.importTasks(original, into: context)
        try context.save()

        let data = try BackupDocument.make(from: context).encoded()
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tasksData = try JSONSerialization.data(withJSONObject: try #require(json["tasks"]))
        let tasks = try PersistenceFixtures.decoder.decode(MyTasksDocument.self, from: tasksData)

        RecordAssert.sameContent(tasks, original)
    }

    // Пустое приложение тоже экспортируется (без краша, пустые списки).
    @Test func пустыеДанные_экспортируютсяБезОшибок() throws {

        let data = try BackupDocument.make(from: container.mainContext).encoded()
        let restored = try BackupDocument.decode(from: data)

        #expect(restored.tasks.tasks.isEmpty)
        #expect(restored.tasks.habits.isEmpty)
    }

    // Сводка считает активные задачи и корзину отдельно — по ней сверяем данные вручную.
    @Test func сводка_считаетАктивныеИКорзинуОтдельно() {
        let backup = BackupDocument(
            format: BackupDocument.formatID,
            version: BackupDocument.currentVersion,
            exportedAt: PersistenceFixtures.date(0),
            tasks: PersistenceFixtures.fullTasksDocument(),
            profile: PersistenceFixtures.profileDocument()
        )

        #expect(backup.summary == "Задач: 2, в корзине: 1, групп: 1, тегов: 2, привычек: 1.")
    }

    // Имя файла содержит дату и время экспорта и не зависит от локали устройства.
    @Test func имяФайла_содержитДатуИВремяЭкспорта() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))

        // 1_700_000_000 = 2023-11-14 22:13:20 UTC
        let name = BackupDocument.defaultFileName(for: PersistenceFixtures.date(0), timeZone: utc)

        #expect(name == "BraineeApp-backup-2023-11-14-2213.json")
    }

    // Обычный mytasks.json (без заголовка бэкапа) не принимается за бэкап.
    @Test func файлБезЗаголовкаБэкапа_отклоняется() throws {
        let data = try PersistenceFixtures.encoder.encode(PersistenceFixtures.fullTasksDocument())

        #expect(throws: BackupDocument.BackupError.self) {
            try BackupDocument.decode(from: data)
        }
    }

    // Бэкап более новой версии формата не читается молча — понятная ошибка.
    @Test func бэкапНовойВерсии_отклоняется() throws {
        let data = Data("""
        { "format": "braineeapp.backup", "version": 99 }
        """.utf8)

        #expect(throws: BackupDocument.BackupError.self) {
            try BackupDocument.decode(from: data)
        }
    }

    // Не JSON вообще — ошибка, без краша.
    @Test func неJSON_бросаетОшибку() {
        #expect(throws: (any Error).self) {
            try BackupDocument.decode(from: Data("не json".utf8))
        }
    }
}
