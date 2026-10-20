//
//  AppDataStore.swift
//  BraineeApp
//
//  Чтение и запись JSON-файлов в Documents и резервной копии в Keychain.

import Foundation

/// Где лежат JSON-файлы и их Keychain-копии.
/// Приложение всегда использует `.standard`; тесты подставляют временную папку и отдельный Keychain service,
/// чтобы не трогать настоящие данные.
struct AppDataStoreLocation {
    var directory: URL
    var keychainService: String

    static var standard: AppDataStoreLocation {
        AppDataStoreLocation(
            directory: AppDataStore.storageDirectory,
            keychainService: KeychainStorage.defaultService
        )
    }
}

/// Ошибки чтения, которые нельзя молча заменить пустыми данными (риск R2 из аудита).
enum AppDataStoreError: LocalizedError {
    /// Файл не разбирается как JSON, Keychain-копии нет. Файл сохранён под именем `preservedAs`.
    case tasksFileCorrupted(preservedAs: String)
    case profileFileCorrupted(preservedAs: String)
    /// Файл не разбирается, Keychain-копии нет; файл не трогали (чтение для миграции SD-2).
    case sourceUnreadable(fileName: String)

    var errorDescription: String? {
        switch self {
        case .tasksFileCorrupted(let name):
            "Файл задач повреждён и не читается, резервной копии в Keychain нет. "
                + "Повреждённый файл сохранён как \(name) в папке BraineeApp. "
                + "После перезапуска приложение откроется без задач."
        case .profileFileCorrupted(let name):
            "Файл профиля повреждён и не читается, резервной копии в Keychain нет. "
                + "Повреждённый файл сохранён как \(name) в папке BraineeApp. "
                + "После перезапуска приложение откроется с пустым профилем."
        case .sourceUnreadable(let name):
            "Файл \(name) повреждён и не читается, резервной копии в Keychain нет. Данные не изменены."
        }
    }
}

enum AppDataStore {
    static let folderName = "BraineeApp"
    static let tasksFileName = "mytasks.json"
    static let profileFileName = "profile.json"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static var storageDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Создаёт папку BraineeApp и при необходимости восстанавливает mytasks.json из Keychain.
    static func prepareStorage(location: AppDataStoreLocation = .standard) throws {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        try reconcileTasksBackupIfNeeded(location: location)
    }

    /// Загружает задачи: сравнивает файл и Keychain, возвращает более свежую копию.
    /// Битый файл не заменяется пустыми данными: он переименовывается, а без Keychain-копии — ошибка.
    /// Ошибка чтения с диска (не битый JSON) пробрасывается, файл не трогаем — она может быть временной.
    static func loadTasks(location: AppDataStoreLocation = .standard) throws -> MyTasksDocument {
        var fileDocument: MyTasksDocument?
        var preservedName: String?
        if let data = try readFileIfExists(named: tasksFileName, location: location) {
            fileDocument = decodeTasksDocument(from: data)
            if fileDocument == nil {
                preservedName = try preserveCorruptFile(named: tasksFileName, location: location)
            }
        }
        let keychainDocument = loadTasksFromKeychain(location: location)

        if let preservedName, keychainDocument == nil {
            throw AppDataStoreError.tasksFileCorrupted(preservedAs: preservedName)
        }

        let resolved = pickNewestTasksDocument(fileDocument, keychainDocument)
        guard var document = resolved else {
            return .empty
        }

        document.normalizeRecords()

        if fileDocument == nil, keychainDocument != nil {
            try saveTasks(document, syncKeychain: false, location: location)
        }

        return document
    }

    /// Исходные данные для миграции SD-2: тот же выбор файл/Keychain, что в `loadTasks`,
    /// но без нормализации (чтобы посчитать, что она отбросит) и без записи на диск.
    /// nil — данных нет ни в файле, ни в Keychain. Битый файл без Keychain-копии — ошибка.
    static func readTasksSource(location: AppDataStoreLocation = .standard) throws -> MyTasksDocument? {
        var fileDocument: MyTasksDocument?
        var fileIsCorrupted = false
        if let data = try readFileIfExists(named: tasksFileName, location: location) {
            fileDocument = try? decoder.decode(MyTasksDocument.self, from: data)
            fileIsCorrupted = fileDocument == nil
        }
        let keychainDocument = KeychainStorage.load(account: tasksFileName, service: location.keychainService)
            .flatMap { try? decoder.decode(MyTasksDocument.self, from: $0) }

        if fileIsCorrupted, keychainDocument == nil {
            throw AppDataStoreError.sourceUnreadable(fileName: tasksFileName)
        }
        return pickNewestTasksDocument(fileDocument, keychainDocument)
    }

    /// Профиль для миграции SD-2: файл, иначе Keychain-копия, без нормализации и записи на диск.
    static func readProfileSource(location: AppDataStoreLocation = .standard) throws -> ProfileDocument? {
        var fileIsCorrupted = false
        if let data = try readFileIfExists(named: profileFileName, location: location) {
            if let document = try? decoder.decode(ProfileDocument.self, from: data) {
                return document
            }
            fileIsCorrupted = true
        }
        if let backup = KeychainStorage.load(account: profileFileName, service: location.keychainService),
           let document = try? decoder.decode(ProfileDocument.self, from: backup) {
            return document
        }
        if fileIsCorrupted {
            throw AppDataStoreError.sourceUnreadable(fileName: profileFileName)
        }
        return nil
    }

    /// Сохраняет mytasks.json; Keychain обновляется отдельно, ошибка Keychain не блокирует запись файла.
    static func saveTasks(
        _ document: MyTasksDocument,
        syncKeychain: Bool = true,
        location: AppDataStoreLocation = .standard
    ) throws {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)

        var normalized = document
        normalized.normalizeRecords()
        normalized.lastSavedAt = .now
        normalized.version = MyTasksDocument.currentVersion

        let data = try encoder.encode(normalized)
        let url = location.directory.appendingPathComponent(tasksFileName)
        try data.write(to: url, options: .atomic)

        if syncKeychain {
            do {
                try KeychainStorage.save(data, account: tasksFileName, service: location.keychainService)
            } catch {
                print("Keychain tasks backup failed: \(error)")
            }
        }
    }

    /// Профиль: файл, иначе Keychain-копия, иначе пустой. Битый файл — по тем же правилам, что и задачи.
    static func loadProfile(location: AppDataStoreLocation = .standard) throws -> ProfileDocument {
        var document: ProfileDocument?
        var preservedName: String?
        if let data = try readFileIfExists(named: profileFileName, location: location) {
            document = try? decoder.decode(ProfileDocument.self, from: data)
            if document == nil {
                preservedName = try preserveCorruptFile(named: profileFileName, location: location)
            }
        }
        if document == nil,
           let backup = KeychainStorage.load(account: profileFileName, service: location.keychainService) {
            document = try? decoder.decode(ProfileDocument.self, from: backup)
        }
        if document == nil, let preservedName {
            throw AppDataStoreError.profileFileCorrupted(preservedAs: preservedName)
        }

        var result = document ?? .empty
        result.normalize()
        return result
    }

    static func saveProfile(_ document: ProfileDocument, location: AppDataStoreLocation = .standard) throws {
        try prepareStorage(location: location)
        var normalized = document
        normalized.normalize()
        let data = try encoder.encode(normalized)
        let url = location.directory.appendingPathComponent(profileFileName)
        try data.write(to: url, options: .atomic)
        try KeychainStorage.save(data, account: profileFileName, service: location.keychainService)
    }

    /// nil — файла нет. Ошибка чтения пробрасывается (раньше молча считалась «файла нет»).
    private static func readFileIfExists(named fileName: String, location: AppDataStoreLocation) throws -> Data? {
        let url = location.directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    /// Переименовывает нечитаемый файл (mytasks.json → mytasks.corrupt-20261020-164300.json),
    /// чтобы его содержимое не было перезаписано. Возвращает новое имя.
    private static func preserveCorruptFile(named fileName: String, location: AppDataStoreLocation) throws -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = (fileName as NSString).deletingPathExtension
        var preservedName = "\(base).corrupt-\(formatter.string(from: .now)).json"
        if FileManager.default.fileExists(atPath: location.directory.appendingPathComponent(preservedName).path) {
            preservedName = "\(base).corrupt-\(formatter.string(from: .now))-\(UUID().uuidString.prefix(8)).json"
        }
        try FileManager.default.moveItem(
            at: location.directory.appendingPathComponent(fileName),
            to: location.directory.appendingPathComponent(preservedName)
        )
        print("AppDataStore: corrupted \(fileName) preserved as \(preservedName)")
        return preservedName
    }

    private static func loadTasksFromKeychain(location: AppDataStoreLocation) -> MyTasksDocument? {
        guard let data = KeychainStorage.load(account: tasksFileName, service: location.keychainService) else {
            return nil
        }
        return decodeTasksDocument(from: data)
    }

    private static func decodeTasksDocument(from data: Data) -> MyTasksDocument? {
        guard var document = try? decoder.decode(MyTasksDocument.self, from: data) else {
            return nil
        }
        document.normalizeRecords()
        return document
    }

    private static func pickNewestTasksDocument(_ file: MyTasksDocument?, _ keychain: MyTasksDocument?) -> MyTasksDocument? {
        switch (file, keychain) {
        case (nil, nil):
            return nil
        case (let file?, nil):
            return file
        case (nil, let keychain?):
            return keychain
        case (let file?, let keychain?):
            return file.contentTimestamp >= keychain.contentTimestamp ? file : keychain
        }
    }

    /// После переустановки копирует Keychain в файл напрямую, без рекурсивного saveTasks.
    private static func reconcileTasksBackupIfNeeded(location: AppDataStoreLocation) throws {
        let url = location.directory.appendingPathComponent(tasksFileName)
        guard !FileManager.default.fileExists(atPath: url.path),
              var keychainDocument = loadTasksFromKeychain(location: location) else {
            return
        }

        keychainDocument.normalizeRecords()
        keychainDocument.lastSavedAt = .now
        keychainDocument.version = MyTasksDocument.currentVersion

        let data = try encoder.encode(keychainDocument)
        try data.write(to: url, options: .atomic)
    }
}
