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

        let tasksURL = storageDirectory.appendingPathComponent(tasksFileName)
        let profileURL = storageDirectory.appendingPathComponent(profileFileName)

        if !FileManager.default.fileExists(atPath: tasksURL.path),
           let backup = KeychainStorage.load(account: tasksFileName) {
            try backup.write(to: tasksURL, options: .atomic)
        }

        if !FileManager.default.fileExists(atPath: profileURL.path),
           let backup = KeychainStorage.load(account: profileFileName) {
            try backup.write(to: profileURL, options: .atomic)
        }
    }

    static func loadTasks() throws -> MyTasksDocument {
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(MyTasksDocument.self, from: data)
    }

    static func saveTasks(_ document: MyTasksDocument) throws {
        try prepareStorage()
        let data = try encoder.encode(document)
        let url = storageDirectory.appendingPathComponent(tasksFileName)
        try data.write(to: url, options: .atomic)
        try KeychainStorage.save(data, account: tasksFileName)
    }

    static func loadProfile() throws -> ProfileDocument {
        let url = storageDirectory.appendingPathComponent(profileFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
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
}
