//
//  WidgetSnapshotBuilder.swift
//  BraineeApp
//
//  Собирает снимок для виджетов из активных задач и привычек.

import Foundation
import WidgetKit

enum WidgetSnapshotBuilder {
    static func build(
        tasks: [TaskItem],
        habits: [Habit],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let stats = TaskStats.compute(from: tasks)
        let todayTasks = tasks
            .filter { !$0.isCompleted && $0.isDueToday }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.sortOrder < rhs.sortOrder
            }
            .prefix(5)
            .map(mapTask)

        let priorityTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue && !rhs.isOverdue }
                return lhs.sortOrder < rhs.sortOrder
            }
            .prefix(5)
            .map(mapTask)

        let sortedHabits = habits.sorted { $0.sortOrder < $1.sortOrder }
        let habitRows = sortedHabits.map { habit in
            WidgetHabitRow(
                id: habit.uuid,
                title: habit.title,
                isCompletedToday: habit.isCompleted(on: now, calendar: calendar)
            )
        }
        let completedToday = habitRows.filter(\.isCompletedToday).count

        return WidgetSnapshot(
            updatedAt: now,
            todayTasks: Array(todayTasks),
            priorityTasks: Array(priorityTasks),
            stats: WidgetStatsSnapshot(
                total: stats.total,
                completed: stats.completed,
                active: stats.active,
                overdue: stats.overdue,
                today: stats.today
            ),
            habits: habitRows,
            habitsCompletedToday: completedToday,
            habitsTotal: habitRows.count
        )
    }

    /// Пишет снимок в App Group и просит WidgetKit обновить таймлайны.
    static func publish(tasks: [TaskItem], habits: [Habit]) {
        let snapshot = build(tasks: tasks, habits: habits)
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func mapTask(_ task: TaskItem) -> WidgetTaskRow {
        WidgetTaskRow(
            id: task.uuid,
            title: task.title,
            priorityTitle: task.priority.title,
            isOverdue: task.isOverdue,
            deadlineText: task.deadlineDisplayText
        )
    }
}
