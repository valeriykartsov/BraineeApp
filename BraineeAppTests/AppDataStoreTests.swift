//
//  AppDataStoreTests.swift
//  BraineeAppTests
//
//  Характеризационные тесты AppDataStore: фиксируют ТЕКУЩЕЕ поведение файла и Keychain-копии
//  перед миграцией на SwiftData (roadmap BASE-1). Каждый тест работает во временной папке
//  и в отдельном Keychain service — настоящие данные приложения не затрагиваются.

import Foundation
import Testing
@testable import BraineeApp

@Suite(.serialized)
struct AppDataStoreTests {

    // MARK: - Задачи: запись и чтение

    // Сохранённый документ читается обратно без потерь: все сущности и поля на месте.
    @Test func сохранениеИЧтениеЗадач_возвращаютТеЖеДанные() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.fullTasksDocument()

        try AppDataStore.saveTasks(original, location: store.location)
        let loaded = try AppDataStore.loadTasks(location: store.location)

        RecordAssert.sameContent(loaded, original)
    }

    // saveTasks пишет и файл, и Keychain-копию с одинаковым содержимым.
    @Test func сохранениеЗадач_пишетФайлИKeychain() throws {
        let store = try TemporaryDataStore()

        try AppDataStore.saveTasks(PersistenceFixtures.fullTasksDocument(), location: store.location)

        let fileData = try Data(contentsOf: store.tasksFileURL)
        let keychainData = try #require(store.keychainData(account: AppDataStore.tasksFileName))
        #expect(fileData == keychainData)
    }

    // saveTasks всегда ставит текущую версию формата и свежий lastSavedAt (по нему выбирается копия).
    @Test func сохранениеЗадач_обновляетВерсиюИДатуСохранения() throws {
        let store = try TemporaryDataStore()
        var old = PersistenceFixtures.fullTasksDocument(lastSavedAt: PersistenceFixtures.date(0))
        old.version = 2
        let before = Date.now.addingTimeInterval(-1)

        try AppDataStore.saveTasks(old, location: store.location)

        let saved = try PersistenceFixtures.decoder.decode(
            MyTasksDocument.self,
            from: Data(contentsOf: store.tasksFileURL)
        )
        #expect(saved.version == MyTasksDocument.currentVersion)
        #expect((saved.lastSavedAt ?? .distantPast) >= before)
    }

    // syncKeychain: false — Keychain не трогается (так пишет loadTasks при восстановлении из копии).
    @Test func сохранениеЗадачБезKeychain_неПишетKeychain() throws {
        let store = try TemporaryDataStore()

        try AppDataStore.saveTasks(
            PersistenceFixtures.fullTasksDocument(),
            syncKeychain: false,
            location: store.location
        )

        #expect(store.tasksFileExists)
        #expect(store.keychainData(account: AppDataStore.tasksFileName) == nil)
    }

    // Нет ни файла, ни Keychain — пустой документ (первый запуск).
    @Test func нетФайлаИKeychain_возвращаетсяПустойДокумент() throws {
        let store = try TemporaryDataStore()

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.isEmpty)
        #expect(loaded.groups.isEmpty)
        #expect(loaded.tags.isEmpty)
        #expect(loaded.habits.isEmpty)
        #expect(!store.tasksFileExists)
    }

    // MARK: - Восстановление из Keychain (переустановка приложения)

    // prepareStorage: файла нет, копия в Keychain есть — файл восстанавливается из копии.
    @Test func нетФайлаЕстьKeychain_prepareStorageВосстанавливаетФайл() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.fullTasksDocument()
        try store.writeTasksKeychain(original)

        try AppDataStore.prepareStorage(location: store.location)

        #expect(store.tasksFileExists)
        let restored = try PersistenceFixtures.decoder.decode(
            MyTasksDocument.self,
            from: Data(contentsOf: store.tasksFileURL)
        )
        RecordAssert.sameContent(restored, original)
    }

    // loadTasks без prepareStorage: берёт Keychain-копию и сам дописывает файл.
    @Test func нетФайлаЕстьKeychain_loadTasksБерётКопиюИПишетФайл() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.fullTasksDocument()
        try store.writeTasksKeychain(original)

        let loaded = try AppDataStore.loadTasks(location: store.location)

        RecordAssert.sameContent(loaded, original)
        #expect(store.tasksFileExists)
    }

    // MARK: - Выбор более свежей копии

    // Файл новее Keychain по lastSavedAt — выбирается файл.
    @Test func файлНовееKeychain_выбираетсяФайл() throws {
        let store = try TemporaryDataStore()
        try store.writeTasksFile(Self.document(title: "из файла", savedAt: 200))
        try store.writeTasksKeychain(Self.document(title: "из Keychain", savedAt: 100))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["из файла"])
    }

    // Keychain новее файла — выбирается Keychain.
    @Test func keychainНовееФайла_выбираетсяKeychain() throws {
        let store = try TemporaryDataStore()
        try store.writeTasksFile(Self.document(title: "из файла", savedAt: 100))
        try store.writeTasksKeychain(Self.document(title: "из Keychain", savedAt: 200))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["из Keychain"])
    }

    // Одинаковая дата — приоритет у файла (сравнение >=).
    @Test func одинаковаяДатаСохранения_выбираетсяФайл() throws {
        let store = try TemporaryDataStore()
        try store.writeTasksFile(Self.document(title: "из файла", savedAt: 100))
        try store.writeTasksKeychain(Self.document(title: "из Keychain", savedAt: 100))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["из файла"])
    }

    // Без lastSavedAt свежесть определяется по самой поздней createdAt задач.
    @Test func безДатыСохранения_свежестьПоCreatedAtЗадач() throws {
        let store = try TemporaryDataStore()
        try store.writeTasksFile(Self.document(title: "старый файл", savedAt: nil, createdAt: 10))
        try store.writeTasksKeychain(Self.document(title: "новый Keychain", savedAt: nil, createdAt: 20))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["новый Keychain"])
    }

    // MARK: - Повреждённые данные (текущее поведение, риск R2 из аудита)

    // Битый файл + целая Keychain-копия — используется копия.
    @Test func битыйФайлЕстьKeychain_используетсяKeychain() throws {
        let store = try TemporaryDataStore()
        try Data("{ не json".utf8).write(to: store.tasksFileURL)
        try store.writeTasksKeychain(Self.document(title: "из Keychain", savedAt: 100))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["из Keychain"])
    }

    // ТЕКУЩЕЕ поведение (риск R2): битый файл без Keychain-копии молча даёт пустой документ.
    // Сам loadTasks файл не перезаписывает — данные теряются при следующем сохранении.
    // BASE-3 должен изменить это поведение; тогда тест нужно обновить.
    @Test func битыйФайлБезKeychain_сейчасВозвращаетсяПустойДокумент() throws {
        let store = try TemporaryDataStore()
        let corrupt = Data("{ не json".utf8)
        try corrupt.write(to: store.tasksFileURL)

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.isEmpty)
        #expect(try Data(contentsOf: store.tasksFileURL) == corrupt)
    }

    // ТЕКУЩЕЕ поведение (риск R3): при чтении привычки сверх 7 молча отбрасываются.
    @Test func восемьПривычек_сейчасПослеЧтенияОстаётсяСемь() throws {
        let store = try TemporaryDataStore()
        var document = Self.document(title: "задача", savedAt: 100)
        document.habits = (0..<8).map { index in
            HabitRecord(id: UUID(), title: "Привычка \(index)", sortOrder: index, createdAt: PersistenceFixtures.date(0))
        }
        try store.writeTasksFile(document)

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.habits.count == Habit.maxCount)
        #expect(!loaded.habits.contains { $0.title == "Привычка 7" })
    }

    // MARK: - Профиль

    // Профиль сохраняется и читается без потерь.
    @Test func сохранениеИЧтениеПрофиля_возвращаютТеЖеДанные() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.profileDocument()

        try AppDataStore.saveProfile(original, location: store.location)
        let loaded = try AppDataStore.loadProfile(location: store.location)

        Self.expectSameProfile(loaded, original)
        #expect(store.keychainData(account: AppDataStore.profileFileName) != nil)
    }

    // Нет profile.json — профиль берётся из Keychain (файл при этом не создаётся).
    @Test func нетФайлаПрофиляЕстьKeychain_используетсяKeychain() throws {
        let store = try TemporaryDataStore()
        let original = PersistenceFixtures.profileDocument()
        try store.writeProfileKeychain(original)

        let loaded = try AppDataStore.loadProfile(location: store.location)

        Self.expectSameProfile(loaded, original)
        #expect(!FileManager.default.fileExists(atPath: store.profileFileURL.path))
    }

    // Битый profile.json — ошибка пробрасывается (в отличие от mytasks.json), bootstrap покажет экран ошибки.
    @Test func битыйФайлПрофиля_бросаетОшибку() throws {
        let store = try TemporaryDataStore()
        try Data("{ не json".utf8).write(to: store.profileFileURL)

        #expect(throws: (any Error).self) {
            try AppDataStore.loadProfile(location: store.location)
        }
    }

    // Нет ни файла, ни копии — пустой профиль с настройками по умолчанию.
    @Test func нетПрофиля_возвращаетсяПустойПрофиль() throws {
        let store = try TemporaryDataStore()

        let loaded = try AppDataStore.loadProfile(location: store.location)

        #expect(loaded.displayName.isEmpty)
        #expect(loaded.avatarBase64 == nil)
        #expect(loaded.accentPaletteRaw == AccentPalette.orange.rawValue)
    }

    // MARK: - Helpers

    private static func document(
        title: String,
        savedAt: TimeInterval?,
        createdAt: TimeInterval = 0
    ) -> MyTasksDocument {
        MyTasksDocument(
            version: MyTasksDocument.currentVersion,
            lastSavedAt: savedAt.map(PersistenceFixtures.date),
            tags: [],
            groups: [],
            tasks: [
                TaskRecord(
                    id: UUID(),
                    title: title,
                    isCompleted: false,
                    deadline: nil,
                    priorityRaw: TaskPriority.medium.rawValue,
                    categoryRaw: TaskCategory.unifiedRaw,
                    createdAt: PersistenceFixtures.date(createdAt),
                    taskDetails: "",
                    sortOrder: 0,
                    groupID: nil,
                    tagIDs: []
                )
            ]
        )
    }

    private static func expectSameProfile(
        _ actual: ProfileDocument,
        _ expected: ProfileDocument,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.displayName == expected.displayName, sourceLocation: sourceLocation)
        #expect(actual.avatarBase64 == expected.avatarBase64, sourceLocation: sourceLocation)
        #expect(actual.age == expected.age, sourceLocation: sourceLocation)
        #expect(actual.genderRaw == expected.genderRaw, sourceLocation: sourceLocation)
        #expect(actual.appThemeRaw == expected.appThemeRaw, sourceLocation: sourceLocation)
        #expect(actual.accentPaletteRaw == expected.accentPaletteRaw, sourceLocation: sourceLocation)
        #expect(actual.createdAt == expected.createdAt, sourceLocation: sourceLocation)
    }
}
