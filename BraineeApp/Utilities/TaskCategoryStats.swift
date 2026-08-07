//
//  TaskCategoryStats.swift
//  BraineeApp
//
//  Расчёт цифр дашборда по разделу. Отдельный тип — чтобы считать и в UI, и в тестах одинаково.

import Foundation

struct TaskCategoryStats: Equatable {
    let total: Int
    let completed: Int
    let active: Int
    let overdue: Int
    let today: Int
    let progress: Double

    /// Считает статистику по уже отфильтрованным активным задачам (без мягко удалённых).
    static func compute(from activeTasks: [TaskItem], category: TaskCategory) -> TaskCategoryStats {
        let tasks = activeTasks.filter { $0.category == category }
        let completed = tasks.filter(\.isCompleted).count
        let overdue = tasks.filter(\.isOverdue).count
        let today = tasks.filter(\.isDueToday).count
        let total = tasks.count
        let active = tasks.filter { !$0.isCompleted }.count
        let progress = total == 0 ? 0.0 : Double(completed) / Double(total)
        return TaskCategoryStats(
            total: total,
            completed: completed,
            active: active,
            overdue: overdue,
            today: today,
            progress: progress
        )
    }
}
