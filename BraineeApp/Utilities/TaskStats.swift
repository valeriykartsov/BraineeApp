//
//  TaskStats.swift
//  BraineeApp
//
//  Цифры дашборда по всем активным задачам.

import Foundation

struct TaskStats: Equatable {
    let total: Int
    let completed: Int
    let active: Int
    let overdue: Int
    let today: Int
    let progress: Double

    /// Статистика по уже отфильтрованным активным задачам (без мягко удалённых).
    static func compute(from tasks: [TaskItem]) -> TaskStats {
        var completed = 0
        var overdue = 0
        var today = 0
        var active = 0
        for task in tasks {
            if task.isCompleted {
                completed += 1
            } else {
                active += 1
            }
            if task.isOverdue { overdue += 1 }
            if task.isDueToday { today += 1 }
        }
        let total = tasks.count
        let progress = total == 0 ? 0.0 : Double(completed) / Double(total)
        return TaskStats(
            total: total,
            completed: completed,
            active: active,
            overdue: overdue,
            today: today,
            progress: progress
        )
    }
}

/// Обратная совместимость имени для старых вызовов/тестов.
typealias TaskCategoryStats = TaskStats
