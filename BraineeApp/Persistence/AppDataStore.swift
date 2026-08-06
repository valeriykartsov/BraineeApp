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
        try restoreTasksFileFromKeychainIfNeeded()
    }

    static func loadTasks() throws -> MyTasksDocument {
        let fileDocument = loadTasksFromFile()
        let keychainDocument = loadTasksFromKeychain()

        let resolved: MyTasksDocument?
        switch (fileDocument, keychainDocument) {
        case (nil, nil):
            resolved = nil
        case (let file?, nil):
            resolved = file
        case (nil, let keychain?):
            resolved = keychain
        case (let file?, let keychain?):
            resolved = mergeTasksDocuments(primary: file, secondary: keychain)
        }

        guard var document = resolved else {
            return .empty
        }

        document.normalizeRecords()

        if fileDocument == nil, keychainDocument != nil {
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
            do {
                try KeychainStorage.save(data, account: tasksFileName)
            } catch {
                print("Keychain tasks backup failed: \(error)")
            }
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

    private static func mergeTasksDocuments(primary: MyTasksDocument, secondary: MyTasksDocument) -> MyTasksDocument {
        var merged = primary
        let tasksByID = Dictionary(uniqueKeysWithValues: merged.tasks.map { ($0.id, $0) })
        var resolvedTasks = tasksByID

        for task in secondary.tasks {
            if let existing = resolvedTasks[task.id] {
                if task.isDeleted && !existing.isDeleted {
                    var updated = existing
                    updated.isDeleted = true
                    updated.deletedAt = task.deletedAt ?? existing.deletedAt ?? existing.createdAt
                    resolvedTasks[task.id] = updated
                }
            } else {
                resolvedTasks[task.id] = task
            }
        }

        merged.tasks = Array(resolvedTasks.values)
        merged.lastSavedAt = maxTimestamp(primary.lastSavedAt, secondary.lastSavedAt)
        return merged
    }

    private static func maxTimestamp(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (nil, nil):
            return nil
        case (let lhs?, nil):
            return lhs
        case (nil, let rhs?):
            return rhs
        case (let lhs?, let rhs?):
            return max(lhs, rhs)
        }
    }

    private static func restoreTasksFileFromKeychainIfNeeded() throws {
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        guard !FileManager.default.fileExists(atPath: url.path),
              let keychainDocument = loadTasksFromKeychain() else {
            return
        }

        try saveTasks(keychainDocument, syncKeychain: false)
    }
}
