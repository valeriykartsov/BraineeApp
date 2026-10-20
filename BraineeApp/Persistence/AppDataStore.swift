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
    static func loadTasks(location: AppDataStoreLocation = .standard) throws -> MyTasksDocument {
        let fileDocument = loadTasksFromFile(location: location)
        let keychainDocument = loadTasksFromKeychain(location: location)

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

    static func loadProfile(location: AppDataStoreLocation = .standard) throws -> ProfileDocument {
        let url = location.directory.appendingPathComponent(profileFileName)
        var document: ProfileDocument
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            document = try decoder.decode(ProfileDocument.self, from: data)
        } else if let backup = KeychainStorage.load(account: profileFileName, service: location.keychainService) {
            document = try decoder.decode(ProfileDocument.self, from: backup)
        } else {
            document = .empty
        }
        document.normalize()
        return document
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

    private static func loadTasksFromFile(location: AppDataStoreLocation) -> MyTasksDocument? {
        let url = location.directory.appendingPathComponent(tasksFileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return decodeTasksDocument(from: data)
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
