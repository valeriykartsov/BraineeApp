//
//  NotificationSnoozes.swift
//  BraineeApp
//
//  «Напомнить через час» (D-46 п. 5): повторы уведомлений о задаче. Служебный файл
//  `Application Support/BraineeApp/notification-snoozes.json` — не SwiftData и не бэкап.
//  Нужен потому, что пересборка уведомлений снимает все запланированные и ставит заново.

import Foundation

struct NotificationSnooze: Codable, Equatable {
    let taskUUID: UUID
    let fireDate: Date
    /// Заголовок исходного уведомления («Напоминание о задаче», «Просроченный дедлайн»).
    let title: String
}

enum NotificationSnoozes {
    static let delay: TimeInterval = 60 * 60

    /// Новый повтор задачи заменяет прежний: у задачи не больше одного.
    static func adding(
        _ snooze: NotificationSnooze,
        to snoozes: [NotificationSnooze]
    ) -> [NotificationSnooze] {
        snoozes.filter { $0.taskUUID != snooze.taskUUID } + [snooze]
    }

    /// Повторы, которые ещё нужно поставить: время не прошло, задача активна (не выполнена, не в корзине).
    static func active(
        _ snoozes: [NotificationSnooze],
        tasks: [TaskItem],
        now: Date
    ) -> [NotificationSnooze] {
        let activeIDs = Set(tasks.filter { !$0.isCompleted && !$0.isSoftDeleted }.map(\.uuid))
        return snoozes.filter { $0.fireDate > now && activeIDs.contains($0.taskUUID) }
    }
}

struct NotificationSnoozesFile {
    static let fileName = "notification-snoozes.json"

    let url: URL

    /// Рядом с хранилищем: `Application Support/BraineeApp/notification-snoozes.json`.
    static func standard() -> NotificationSnoozesFile {
        NotificationSnoozesFile(
            url: ModelContainerFactory.standardStoreURL
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
        )
    }

    /// Нет файла или он битый — повторов нет (потеря повтора не трогает данные задач).
    func load() -> [NotificationSnooze] {
        guard let data = try? Data(contentsOf: url),
              let snoozes = try? JSONDecoder().decode([NotificationSnooze].self, from: data)
        else { return [] }
        return snoozes
    }

    func save(_ snoozes: [NotificationSnooze]) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snoozes).write(to: url, options: .atomic)
        } catch {
            print("NotificationSnoozes: save failed: \(error)")
        }
    }
}
