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
        let snapshot = WidgetSnapshotStore.load()
        let calendar = Calendar.current
        var entries = [BraineeWidgetEntry(date: .now, snapshot: snapshot)]
        // В полночь меняется дата на виджете «Календарь», а счётчики «сегодня» становятся вчерашними.
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) {
            entries.append(BraineeWidgetEntry(date: midnight, snapshot: snapshot))
        }
        let next = calendar.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(next)))
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
            stats: WidgetStatsSnapshot(total: 8, completed: 3, active: 5, overdue: 1, today: 3, todayCompleted: 1),
            habits: [
                WidgetHabitRow(id: UUID(), title: "Зарядка", isCompletedToday: true),
                WidgetHabitRow(id: UUID(), title: "Чтение", isCompletedToday: false)
            ],
            habitsCompletedToday: 1,
            habitsTotal: 2
        )
    }
}
