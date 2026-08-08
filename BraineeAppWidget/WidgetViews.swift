//
//  WidgetViews.swift
//  BraineeAppWidget
//
//  UI четырёх виджетов: 2×small, medium, large.

import SwiftUI
import WidgetKit

// MARK: - Small: задачи сегодня

struct TodayTasksWidgetView: View {
    var entry: BraineeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Сегодня", systemImage: "checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.orange)

            let tasks = Array(entry.snapshot.todayTasks.prefix(3))
            if tasks.isEmpty {
                Text("Нет задач на сегодня")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(tasks) { task in
                    HStack(alignment: .top, spacing: 4) {
                        Circle()
                            .fill(task.isOverdue ? Color.red : Color.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(WidgetSnapshotStore.openURL)
    }
}

// MARK: - Small: привычки

struct HabitsProgressWidgetView: View {
    var entry: BraineeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Привычки", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.orange)

            if entry.snapshot.habitsTotal == 0 {
                Text("Нет привычек")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Text("\(entry.snapshot.habitsCompletedToday)/\(entry.snapshot.habitsTotal)")
                    .font(.title2.weight(.bold))
                ProgressView(value: entry.snapshot.habitsProgress)
                    .tint(.orange)
                Text(progressCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(WidgetSnapshotStore.openURL)
    }

    private var progressCaption: String {
        let percent = Int((entry.snapshot.habitsProgress * 100).rounded())
        return "\(percent)% за сегодня"
    }
}

// MARK: - Medium: задачи + дашборд

struct TasksDashboardWidgetView: View {
    var entry: BraineeWidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Задачи", systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)

                let tasks = displayTasks
                if tasks.isEmpty {
                    Text("Нет активных задач")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Дашборд")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                statRow("Всего", "\(entry.snapshot.stats.total)")
                statRow("Активные", "\(entry.snapshot.stats.active)")
                statRow("Сегодня", "\(entry.snapshot.stats.today)")
                statRow("Просрочено", "\(entry.snapshot.stats.overdue)", warn: entry.snapshot.stats.overdue > 0)
                ProgressView(value: entry.snapshot.stats.progress)
                    .tint(.orange)
                Spacer(minLength: 0)
            }
            .frame(width: 110, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(WidgetSnapshotStore.openURL)
    }

    private var displayTasks: [WidgetTaskRow] {
        let today = entry.snapshot.todayTasks
        if !today.isEmpty { return Array(today.prefix(4)) }
        return Array(entry.snapshot.priorityTasks.prefix(4))
    }

    private func statRow(_ title: String, _ value: String, warn: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(warn ? Color.red : Color.primary)
        }
    }
}

// MARK: - Large: задачи + привычки

struct TasksHabitsWidgetView: View {
    var entry: BraineeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Задачи", systemImage: "checklist")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.orange)
                    let tasks = displayTasks
                    if tasks.isEmpty {
                        Text("Нет активных задач")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tasks) { task in
                            HStack(spacing: 6) {
                                Text(task.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if let deadline = task.deadlineText {
                                    Text(deadline)
                                        .font(.caption2)
                                        .foregroundStyle(task.isOverdue ? Color.red : .secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Сводка")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(entry.snapshot.stats.active) акт.")
                        .font(.caption)
                    Text("\(entry.snapshot.stats.today) сег.")
                        .font(.caption)
                    Text("\(entry.snapshot.stats.overdue) проср.")
                        .font(.caption)
                        .foregroundStyle(entry.snapshot.stats.overdue > 0 ? Color.red : .primary)
                }
                .frame(width: 88, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Привычки", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.orange)
                    Spacer()
                    Text("\(entry.snapshot.habitsCompletedToday)/\(entry.snapshot.habitsTotal)")
                        .font(.caption.weight(.semibold))
                }
                if entry.snapshot.habits.isEmpty {
                    Text("Нет привычек")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.snapshot.habits.prefix(5)) { habit in
                        HStack(spacing: 6) {
                            Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(habit.isCompletedToday ? Color.orange : .secondary)
                                .font(.caption)
                            Text(habit.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(WidgetSnapshotStore.openURL)
    }

    private var displayTasks: [WidgetTaskRow] {
        let today = entry.snapshot.todayTasks
        if !today.isEmpty { return Array(today.prefix(5)) }
        return Array(entry.snapshot.priorityTasks.prefix(5))
    }
}
