//
//  ModelContainerFactory.swift
//  BraineeApp
//
//  Единое место создания ModelContainer (roadmap SD-1): схема и план миграций задаются здесь.
//  Приложение работает от `.persistent(url: standardStoreURL)` (SD-3); `.inMemory` — тесты и превью.

import Foundation
import SwiftData

enum ModelContainerFactory {
    enum Storage: Equatable {
        /// Данные только в памяти (тесты, превью).
        case inMemory
        /// SQLite-хранилище по явно заданному адресу файла.
        case persistent(url: URL)
    }

    static var schema: Schema { Schema(versionedSchema: CurrentSchema.self) }

    /// Хранилище приложения: `Application Support/BraineeApp/BraineeApp.store`.
    /// Не в App Group — виджет читает снимок, а не SwiftData.
    static var standardStoreURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppDataStore.folderName, isDirectory: true)
            .appendingPathComponent("BraineeApp.store")
    }

    static func make(_ storage: Storage) throws -> ModelContainer {
        let configuration: ModelConfiguration
        switch storage {
        case .inMemory:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        case .persistent(let url):
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // CloudKit явно выключен: синхронизация — отдельное решение, а `#Unique` с ней несовместим.
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: BraineeMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
