//
//  AppDataStore.swift
//  BraineeApp
//

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

    static func prepareStorage() throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try reconcileTasksBackupIfNeeded()
    }

    static func loadTasks() throws -> MyTasksDocument {
        let fileDocument = loadTasksFromFile()
        let keychainDocument = loadTasksFromKeychain()

        let resolved = pickNewestTasksDocument(fileDocument, keychainDocument)
        var document = resolved ?? .empty
        document.normalizeRecords()

        if resolved != nil {
            try saveTasks(document)
        }

        return document
    }

    static func saveTasks(_ document: MyTasksDocument, syncKeychain: Bool = true) throws {
        try prepareStorage()

        var normalized = document
        normalized.normalizeRecords()
        normalized.lastSavedAt = .now
        normalized.version = MyTasksDocument.currentVersion

        let data = try encoder.encode(normalized)
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        try data.write(to: url, options: .atomic)

        if syncKeychain {
            try KeychainStorage.save(data, account: tasksFileName)
        }
    }

    static func loadProfile() throws -> ProfileDocument {
        let url = storageDirectory.appendingPathComponent(profileFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            if let backup = KeychainStorage.load(account: profileFileName) {
                return try decoder.decode(ProfileDocument.self, from: backup)
            }
            return .empty
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ProfileDocument.self, from: data)
    }

    static func saveProfile(_ document: ProfileDocument) throws {
        try prepareStorage()
        let data = try encoder.encode(document)
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

    private static func reconcileTasksBackupIfNeeded() throws {
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        let fileDocument = loadTasksFromFile()
        let keychainDocument = loadTasksFromKeychain()

        guard fileDocument == nil, let keychainDocument else { return }

        try saveTasks(keychainDocument, syncKeychain: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            let data = try encoder.encode(keychainDocument)
            try data.write(to: url, options: .atomic)
        }
    }
}
