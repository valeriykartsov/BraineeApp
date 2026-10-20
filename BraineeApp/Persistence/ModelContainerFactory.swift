//
//  ModelContainerFactory.swift
//  BraineeApp
//
//  Единое место создания ModelContainer (roadmap SD-1): схема и план миграций задаются здесь.
//  Приложение пока использует только `.inMemory` — постоянное хранилище включается в SD-3,
//  после того как из `bootstrap` уйдёт `clearAllData` (риск R1).

import Foundation
import SwiftData

enum ModelContainerFactory {
    enum Storage: Equatable {
        /// Данные только в памяти; источник правды — JSON (текущий режим приложения).
        case inMemory
        /// SQLite-хранилище по явно заданному адресу файла. Пока используется только в тестах.
        case persistent(url: URL)
    }

    static var schema: Schema { Schema(versionedSchema: CurrentSchema.self) }

    static func make(_ storage: Storage) throws -> ModelContainer {
        let configuration: ModelConfiguration
        switch storage {
        case .inMemory:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        case .persistent(let url):
            configuration = ModelConfiguration(schema: schema, url: url)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: BraineeMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
