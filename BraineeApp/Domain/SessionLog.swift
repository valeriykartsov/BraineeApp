//
//  SessionLog.swift
//  BraineeApp
//
//  Журнал действий за текущую сессию (п. 16): только в памяти, исчезает при выгрузке приложения.
//  Не SwiftData, не файл, не бэкап; никуда не отправляется (LLM и виджеты его не видят).

import Foundation
import Combine

struct SessionLogEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case task, group, tag, habit, profile, settings, backup, pomodoro
    }

    let id = UUID()
    let date: Date
    let kind: Kind
    /// Что произошло: «Задача изменена».
    let title: String
    /// С чем: название задачи, папки, настройки.
    let subject: String?
    /// Строки «поле: было → стало».
    let changes: [String]
}

@MainActor
final class SessionLog: ObservableObject {
    static let shared = SessionLog()
    static let maxEntries = 500

    /// Новые сверху; не больше `maxEntries`.
    @Published private(set) var entries: [SessionLogEntry] = []

    private let now: () -> Date

    init(now: @escaping () -> Date = { .now }) {
        self.now = now
    }

    func add(_ kind: SessionLogEntry.Kind, _ title: String, subject: String? = nil, changes: [String] = []) {
        entries.insert(
            SessionLogEntry(date: now(), kind: kind, title: title, subject: subject, changes: changes),
            at: 0
        )
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
    }
}
