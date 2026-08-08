//
//  WidgetSnapshot.swift
//  BraineeShared
//
//  Снимок данных для виджетов (App Group). Читает расширение, пишет основное приложение.

import Foundation

enum WidgetSnapshotStore {
    static let appGroupID = "group.valeravalera.BraineeApp"
    static let fileName = "widget_snapshot.json"
    static let openURL = URL(string: "braineeapp://open")!

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL else {
            print("WidgetSnapshot: App Group container unavailable")
            return
        }
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            print("WidgetSnapshot save failed: \(error.localizedDescription)")
        }
    }

    static func load() -> WidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

struct WidgetSnapshot: Codable, Equatable {
    var updatedAt: Date
    var todayTasks: [WidgetTaskRow]
    var priorityTasks: [WidgetTaskRow]
    var stats: WidgetStatsSnapshot
    var habits: [WidgetHabitRow]
    var habitsCompletedToday: Int
    var habitsTotal: Int

    static let empty = WidgetSnapshot(
        updatedAt: .distantPast,
        todayTasks: [],
        priorityTasks: [],
        stats: .zero,
        habits: [],
        habitsCompletedToday: 0,
        habitsTotal: 0
    )

    var habitsProgress: Double {
        guard habitsTotal > 0 else { return 0 }
        return Double(habitsCompletedToday) / Double(habitsTotal)
    }
}

struct WidgetTaskRow: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var priorityTitle: String
    var isOverdue: Bool
    var deadlineText: String?
}

struct WidgetHabitRow: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var isCompletedToday: Bool
}

struct WidgetStatsSnapshot: Codable, Equatable {
    var total: Int
    var completed: Int
    var active: Int
    var overdue: Int
    var today: Int

    static let zero = WidgetStatsSnapshot(
        total: 0,
        completed: 0,
        active: 0,
        overdue: 0,
        today: 0
    )

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
