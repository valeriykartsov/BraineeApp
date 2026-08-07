//
//  AppDataStore.swift
//  BraineeApp
//
//  Чтение и запись JSON-файлов в Documents и резервной копии в Keychain.

import Foundation

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
    static func prepareStorage() throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try reconcileTasksBackupIfNeeded()
    }

    /// Загружает задачи: сравнивает файл и Keychain, возвращает более свежую копию.
    static func loadTasks() throws -> MyTasksDocument {
        let fileDocument = loadTasksFromFile()
        let keychainDocument = loadTasksFromKeychain()

        let resolved = pickNewestTasksDocument(fileDocument, keychainDocument)
        guard var document = resolved else {
            return .empty
        }

        document.normalizeRecords()

        if fileDocument == nil, keychainDocument != nil {
            try saveTasks(document, syncKeychain: false)
        }

        return document
    }

    /// Сохраняет mytasks.json; Keychain обновляется отдельно, ошибка Keychain не блокирует запись файла.
    static func saveTasks(_ document: MyTasksDocument, syncKeychain: Bool = true) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        var normalized = document
        normalized.normalizeRecords()
        normalized.lastSavedAt = .now
        normalized.version = MyTasksDocument.currentVersion

        let data = try encoder.encode(normalized)
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        try data.write(to: url, options: .atomic)

        if syncKeychain {
            do {
                try KeychainStorage.save(data, account: tasksFileName)
            } catch {
                print("Keychain tasks backup failed: \(error)")
            }
        }
    }

    static func loadProfile() throws -> ProfileDocument {
        let url = storageDirectory.appendingPathComponent(profileFileName)
        var document: ProfileDocument
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            document = try decoder.decode(ProfileDocument.self, from: data)
        } else if let backup = KeychainStorage.load(account: profileFileName) {
            document = try decoder.decode(ProfileDocument.self, from: backup)
        } else {
            document = .empty
        }
        document.normalize()
        return document
    }

    static func saveProfile(_ document: ProfileDocument) throws {
        try prepareStorage()
        var normalized = document
        normalized.normalize()
        let data = try encoder.encode(normalized)
        let url = storageDirectory.appendingPathComponent(profileFileName)
        try data.write(to: url, options: .atomic)
        try KeychainStorage.save(data, account: profileFileName)
    }

    private static func loadTasksFromFile() -> MyTasksDocument? {
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return decodeTasksDocument(from: data)
    }

    private static func loadTasksFromKeychain() -> MyTasksDocument? {
        guard let data = KeychainStorage.load(account: tasksFileName) else { return nil }
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
    private static func reconcileTasksBackupIfNeeded() throws {
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        guard !FileManager.default.fileExists(atPath: url.path),
              var keychainDocument = loadTasksFromKeychain() else {
            return
        }

        keychainDocument.normalizeRecords()
        keychainDocument.lastSavedAt = .now
        keychainDocument.version = MyTasksDocument.currentVersion

        let data = try encoder.encode(keychainDocument)
        try data.write(to: url, options: .atomic)
    }
}
