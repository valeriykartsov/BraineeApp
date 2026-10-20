//
//  SchemaV1.swift
//  BraineeApp
//
//  Версионированная схема SwiftData (roadmap SD-1, вариант А).
//  V1 ссылается на текущие классы моделей из Models/. Когда появится SchemaV2,
//  V1 нужно «заморозить»: скопировать классы в `extension SchemaV1` в их нынешнем виде,
//  иначе SwiftData не сможет отличить старую схему от новой.

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            TaskGroup.self,
            TaskTag.self,
            UserProfile.self,
            Habit.self,
        ]
    }
}

/// План миграций постоянного хранилища. Пока одна версия — этапов нет.
enum BraineeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}

/// Текущая версия схемы — менять здесь при добавлении новой версии.
typealias CurrentSchema = SchemaV1
