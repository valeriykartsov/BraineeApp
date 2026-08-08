//
//  WidgetTimeline.swift
//  BraineeAppWidget
//
//  Общий провайдер таймлайна: читает снимок из App Group.

import WidgetKit
import SwiftUI

struct BraineeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BraineeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BraineeWidgetEntry {
        BraineeWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BraineeWidgetEntry) -> Void) {
        completion(BraineeWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BraineeWidgetEntry>) -> Void) {
        let entry = BraineeWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: .now,
            todayTasks: [
                WidgetTaskRow(
                    id: UUID(),
                    title: "Подготовить отчёт",
                    priorityTitle: "Высокий",
                    isOverdue: false,
                    deadlineText: "сегодня"
                ),
                WidgetTaskRow(
                    id: UUID(),
                    title: "Созвон с командой",
                    priorityTitle: "Средний",
                    isOverdue: false,
                    deadlineText: "сегодня"
                )
            ],
            priorityTasks: [],
            stats: WidgetStatsSnapshot(total: 8, completed: 3, active: 5, overdue: 1, today: 2),
            habits: [
                WidgetHabitRow(id: UUID(), title: "Зарядка", isCompletedToday: true),
                WidgetHabitRow(id: UUID(), title: "Чтение", isCompletedToday: false)
            ],
            habitsCompletedToday: 1,
            habitsTotal: 2
        )
    }
}
