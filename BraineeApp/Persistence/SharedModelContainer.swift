//
//  SharedModelContainer.swift
//  BraineeApp
//
//  Одно хранилище на процесс: его открывает приложение и им же пользуется `AppDelegate`,
//  когда кнопка уведомления запускает приложение в фоне без экрана (D-46).

import SwiftData

@MainActor
enum SharedModelContainer {
    /// Хранилище V1 при первом запуске переводится на V2 с бэкапом и сверкой (`SchemaUpgrade`, D-39).
    static let result = Result {
        try SchemaUpgrade.standard.openStore()
    }
}
