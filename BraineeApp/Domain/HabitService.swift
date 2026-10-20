//
//  HabitService.swift
//  BraineeApp
//
//  Привычки (roadmap DOM-2b): создание, переименование, отметка дня, удаление, порядок.
//  Раньше логика жила в HabitsView.

import Foundation
import SwiftData

@MainActor
struct HabitService {
    let context: ModelContext
    /// См. TaskService.onChange.
    var onChange: (ModelContext) -> Void = { $0.persistToJSON() }

    /// Привычки в порядке отображения.
    var habits: [Habit] {
        context.fetchHabits()
    }

    var canAddMore: Bool {
        habits.count < Habit.maxCount
    }

    /// Новая привычка — в конец. Не больше Habit.maxCount, пустое название не принимается.
    @discardableResult
    func create(title: String) -> Habit? {
        let current = habits
        guard current.count < Habit.maxCount, TaskInputValidation.canSaveTitle(title) else { return nil }
        let nextOrder = (current.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(title: TaskInputValidation.normalizedTitle(title), sortOrder: nextOrder)
        context.insert(habit)
        onChange(context)
        return habit
    }

    /// Возвращает false, если название пустое (привычка не изменена).
    @discardableResult
    func rename(_ habit: Habit, to title: String) -> Bool {
        guard TaskInputValidation.canSaveTitle(title) else { return false }
        habit.title = TaskInputValidation.normalizedTitle(title)
        onChange(context)
        return true
    }

    /// Отметка дня. День приводится к допустимому диапазону (не позже сегодня и не раньше
    /// HabitDaySelection.earliestAllowed). Возвращает, отмечена ли привычка в этот день после переключения.
    @discardableResult
    func toggle(_ habit: Habit, on day: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let allowedDay = HabitDaySelection.clamp(day, relativeTo: now, calendar: calendar)
        habit.toggleCompletion(on: allowedDay, calendar: calendar)
        onChange(context)
        return habit.isCompleted(on: allowedDay, calendar: calendar)
    }

    func delete(_ habit: Habit) {
        context.delete(habit)
        onChange(context)
    }

    /// Живое вытеснение при перетаскивании: меняет порядок в памяти, без сохранения
    /// (сохранение — один раз в saveOrder, когда перетаскивание закончилось).
    func move(_ draggedID: UUID, onto targetID: UUID) {
        var ordered = habits
        guard let fromIndex = ordered.firstIndex(where: { $0.uuid == draggedID }),
              let toIndex = ordered.firstIndex(where: { $0.uuid == targetID }),
              fromIndex != toIndex else {
            return
        }
        let dragged = ordered.remove(at: fromIndex)
        ordered.insert(dragged, at: toIndex)
        for (index, habit) in ordered.enumerated() {
            habit.sortOrder = index
        }
    }

    func saveOrder() {
        onChange(context)
    }
}
