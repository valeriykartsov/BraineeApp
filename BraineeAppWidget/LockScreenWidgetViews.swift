//
//  LockScreenWidgetViews.swift
//  BraineeAppWidget
//
//  UI виджетов экрана блокировки. Цвет задаёт система (одноцветный режим),
//  поэтому акцент — только через `widgetAccentable()`. Нажатие — «Календарь» на сегодня.

import SwiftUI
import WidgetKit

// MARK: - 1×1: календарь

struct LockScreenCalendarWidgetView: View {
    var entry: BraineeWidgetEntry

    private var isFresh: Bool {
        entry.snapshot.isFresh(at: entry.date)
    }

    private var stats: WidgetStatsSnapshot {
        entry.snapshot.stats
    }

    /// «осталось/всего»; прочерк — снимок вчерашний и задач на сегодня не знаем.
    private var tasksText: String {
        guard isFresh else { return "—" }
        return "\(stats.todayRemaining)/\(stats.today)"
    }

    private var accessibilityText: String {
        guard isFresh else { return "Задачи на сегодня: откройте приложение" }
        return "Задачи на сегодня: осталось \(stats.todayRemaining) из \(stats.today)"
    }

    var body: some View {
        VStack(spacing: -1) {
            Text(entry.date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
            Text(entry.date, format: .dateTime.day())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .widgetAccentable()
            Text(tasksText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(entry.date, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(accessibilityText)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
        .widgetURL(WidgetSnapshotStore.calendarURL)
    }
}

// MARK: - 2×1: прогресс за сегодня

struct LockScreenTodayWidgetView: View {
    var entry: BraineeWidgetEntry

    private var isFresh: Bool {
        entry.snapshot.isFresh(at: entry.date)
    }

    private var snapshot: WidgetSnapshot {
        entry.snapshot
    }

    /// Отметки привычек обнуляются каждый день: во вчерашнем снимке на сегодня отмечено 0.
    private var habitsDone: Int {
        isFresh ? snapshot.habitsCompletedToday : 0
    }

    private var habitsValue: String {
        snapshot.habitsTotal == 0 ? "нет" : "\(habitsDone) из \(snapshot.habitsTotal)"
    }

    private var habitsProgress: Double {
        isFresh ? snapshot.habitsProgress : 0
    }

    private var tasksValue: String {
        guard isFresh else { return "—" }
        let stats = snapshot.stats
        return stats.today == 0 ? "нет" : "ещё \(stats.todayRemaining) из \(stats.today)"
    }

    private var tasksProgress: Double {
        isFresh ? snapshot.stats.todayProgress : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            progressRow(
                title: "Привычки",
                systemImage: "flame.fill",
                value: habitsValue,
                progress: habitsProgress
            )
            progressRow(
                title: "Задачи",
                systemImage: "checklist",
                value: tasksValue,
                progress: tasksProgress
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(WidgetSnapshotStore.calendarURL)
    }

    private func progressRow(
        title: String,
        systemImage: String,
        value: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .widgetAccentable()
                Text(title)
                    .fontWeight(.semibold)
                Spacer(minLength: 4)
                Text(value)
                    .monospacedDigit()
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .widgetAccentable()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

#Preview("Календарь", as: .accessoryCircular) {
    LockScreenCalendarWidget()
} timeline: {
    BraineeWidgetEntry(date: .now, snapshot: .placeholder)
    BraineeWidgetEntry(date: .now.addingTimeInterval(86_400), snapshot: .placeholder)
}

#Preview("Сегодня", as: .accessoryRectangular) {
    LockScreenTodayWidget()
} timeline: {
    BraineeWidgetEntry(date: .now, snapshot: .placeholder)
    BraineeWidgetEntry(date: .now.addingTimeInterval(86_400), snapshot: .placeholder)
}
