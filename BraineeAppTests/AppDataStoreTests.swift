//
//  AppDataStoreTests.swift
//  BraineeAppTests
//
//  Тесты AppDataStore: поведение файла и Keychain-копии (BASE-1), защита от битых файлов (BASE-3).
//  Каждый тест работает во временной папке
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

    // MARK: - Повреждённые данные (BASE-3, риск R2 из аудита)

    // Битый файл + целая Keychain-копия: используется копия, битый файл сохранён под другим именем,
    // mytasks.json переписан из копии.
    @Test func битыйФайлЕстьKeychain_используетсяKeychainИФайлСохранён() throws {
        let store = try TemporaryDataStore()
        let corrupt = Data("{ не json".utf8)
        try corrupt.write(to: store.tasksFileURL)
        try store.writeTasksKeychain(Self.document(title: "из Keychain", savedAt: 100))

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.map(\.title) == ["из Keychain"])
        let preserved = store.corruptFiles(of: AppDataStore.tasksFileName)
        #expect(preserved.count == 1)
        #expect(try preserved.first.map { try Data(contentsOf: $0) } == corrupt)
        let rewritten = try PersistenceFixtures.decoder.decode(
            MyTasksDocument.self,
            from: Data(contentsOf: store.tasksFileURL)
        )
        #expect(rewritten.tasks.map(\.title) == ["из Keychain"])
    }

    // Битый файл без Keychain-копии: ошибка вместо пустых данных, содержимое файла сохранено.
    @Test func битыйФайлБезKeychain_ошибкаИФайлСохранён() throws {
        let store = try TemporaryDataStore()
        let corrupt = Data("{ не json".utf8)
        try corrupt.write(to: store.tasksFileURL)

        #expect(throws: AppDataStoreError.self) {
            try AppDataStore.loadTasks(location: store.location)
        }

        #expect(!store.tasksFileExists)
        let preserved = store.corruptFiles(of: AppDataStore.tasksFileName)
        #expect(preserved.count == 1)
        #expect(try preserved.first.map { try Data(contentsOf: $0) } == corrupt)
    }

    // Битый файл и битая Keychain-копия — тоже ошибка, не пустые данные.
    @Test func битыйФайлИБитыйKeychain_ошибка() throws {
        let store = try TemporaryDataStore()
        try Data("{ не json".utf8).write(to: store.tasksFileURL)
        try KeychainStorage.save(
            Data("тоже не json".utf8),
            account: AppDataStore.tasksFileName,
            service: store.location.keychainService
        )

        #expect(throws: AppDataStoreError.self) {
            try AppDataStore.loadTasks(location: store.location)
        }
    }

    // После ошибки следующий запуск открывается без задач; сохранённый битый файл не трогается.
    @Test func послеОшибки_следующийЗапускПустойИБитыйФайлЦел() throws {
        let store = try TemporaryDataStore()
        let corrupt = Data("{ не json".utf8)
        try corrupt.write(to: store.tasksFileURL)
        _ = try? AppDataStore.loadTasks(location: store.location)

        let loaded = try AppDataStore.loadTasks(location: store.location)

        #expect(loaded.tasks.isEmpty)
        #expect(try store.corruptFiles(of: AppDataStore.tasksFileName).map { try Data(contentsOf: $0) } == [corrupt])
    }

    // Файл есть, но не читается с диска (нет прав): ошибка, файл не переименовывается —
    // это может быть временной проблемой, а не порчей данных.
    @Test func файлНеЧитаетсяСДиска_ошибкаФайлНаМесте() throws {
        let store = try TemporaryDataStore()
        try store.writeTasksFile(Self.document(title: "задача", savedAt: 100))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: store.tasksFileURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: store.tasksFileURL.path)
        }

        #expect(throws: (any Error).self) {
            try AppDataStore.loadTasks(location: store.location)
        }

        #expect(store.tasksFileExists)
        #expect(store.corruptFiles(of: AppDataStore.tasksFileName).isEmpty)
    }

    // Текст ошибки понятен пользователю и называет сохранённый файл.
    @Test func текстОшибки_называетСохранённыйФайл() {
        let error = AppDataStoreError.tasksFileCorrupted(preservedAs: "mytasks.corrupt-20261020-164300.json")

        #expect(error.localizedDescription.contains("mytasks.corrupt-20261020-164300.json"))
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

    // Битый profile.json без Keychain-копии: ошибка, файл сохранён под другим именем.
    // Следующий запуск уже не падает — пустой профиль (раньше ошибка повторялась при каждом запуске).
    @Test func битыйФайлПрофиляБезKeychain_ошибкаИФайлСохранён() throws {
        let store = try TemporaryDataStore()
        let corrupt = Data("{ не json".utf8)
        try corrupt.write(to: store.profileFileURL)

        #expect(throws: AppDataStoreError.self) {
            try AppDataStore.loadProfile(location: store.location)
        }
        #expect(try store.corruptFiles(of: AppDataStore.profileFileName).map { try Data(contentsOf: $0) } == [corrupt])

        let next = try AppDataStore.loadProfile(location: store.location)
        #expect(next.displayName.isEmpty)
    }

    // Битый profile.json + целая Keychain-копия — используется копия.
    @Test func битыйФайлПрофиляЕстьKeychain_используетсяKeychain() throws {
        let store = try TemporaryDataStore()
        try Data("{ не json".utf8).write(to: store.profileFileURL)
        let original = PersistenceFixtures.profileDocument()
        try store.writeProfileKeychain(original)

        let loaded = try AppDataStore.loadProfile(location: store.location)

        Self.expectSameProfile(loaded, original)
        #expect(store.corruptFiles(of: AppDataStore.profileFileName).count == 1)
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
