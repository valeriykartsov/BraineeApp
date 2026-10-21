//
//  TaskService.swift
//  BraineeApp
//
//  Единая точка изменения задач (roadmap DOM-1): создание, редактирование, отметка
//  выполнения, смена статуса, мягкое удаление. Раньше эта логика была скопирована
//  в TaskSectionView, CalendarWeekView и EisenhowerQuadrantDetailView.
//  Сервис не знает о SwiftUI: анимации и вибрация остаются во View.

import Foundation
import SwiftData

@MainActor
struct TaskService {
    let context: ModelContext
    /// Что сделать после изменения. В приложении — сохранить хранилище, обновить виджет и уведомления
    /// (`AppSideEffects`); в тестах подменяется, чтобы не трогать виджет и уведомления.
    var onChange: (ModelContext) -> Void = { $0.didChange() }
    /// Текущее время для updatedAt; в тестах подменяется фиксированной датой.
    var now: () -> Date = { .now }

    /// Новая задача — всегда со статусом «Новая», в конце списка активных задач.
    @discardableResult
    func create(from form: TaskFormData) -> TaskItem {
        let nextOrder = (context.fetchActiveTasks().map(\.sortOrder).max() ?? -1) + 1
        let task = TaskItem(
            title: form.title,
            deadline: form.deadline,
            hasDeadlineTime: form.hasDeadlineTime,
            reminderOffsets: form.reminderOffsets,
            priority: form.priority,
            category: .tasks,
            status: .new,
            createdAt: now(),
            taskDetails: form.taskDetails,
            sortOrder: nextOrder
        )
        context.insert(task)
        // Теги — после insert: связь «многие ко многим», заданная в init до вставки,
        // становится видна SwiftData только после save(); так она видна сразу.
        task.tags = form.selectedTags
        onChange(context)
        return task
    }

    func update(_ task: TaskItem, from form: TaskFormData) {
        task.title = form.title
        task.deadline = form.deadline
        task.hasDeadlineTime = form.hasDeadlineTime
        task.reminderOffsets = form.reminderOffsets
        task.priority = form.priority
        task.status = form.status
        task.category = .tasks
        task.taskDetails = form.taskDetails
        task.tags = form.selectedTags
        task.updatedAt = now()
        onChange(context)
    }

    /// Чекбокс: выполненная уходит в конец своей группы (или во «Входящих»),
    /// снятие отметки — в конец незакрытых той же группы.
    func toggleCompletion(_ task: TaskItem) {
        task.applyCompletionToggle()

        let peers = context.fetchActiveTasks().filter { peer in
            if let groupUUID = task.group?.uuid {
                return peer.group?.uuid == groupUUID
            }
            return peer.group == nil
        }
        if task.isCompleted {
            TaskSortHelper.moveToEnd(of: peers, task: task)
        } else {
            let incompletePeers = peers.filter { !$0.isCompleted || $0.uuid == task.uuid }
            TaskSortHelper.moveToEnd(of: incompletePeers, task: task)
        }
        task.updatedAt = now()
        onChange(context)
    }

    /// Смена статуса из канбана (порядок не меняется).
    func setStatus(_ task: TaskItem, _ status: TaskStatus) {
        task.status = status
        task.updatedAt = now()
        onChange(context)
    }

    /// В «Удалённые»: задача остаётся в базе, окончательное удаление — только из корзины.
    func softDelete(_ task: TaskItem) {
        task.isSoftDeleted = true
        task.deletedAt = now()
        task.updatedAt = now()
        try? context.save()
        onChange(context)
    }

    /// Перенос в группу (drag-and-drop) или во «Входящие» (`group == nil`): в конец целевой группы.
    /// Задачи из корзины не переносятся.
    func move(_ task: TaskItem, to group: TaskGroup?) {
        guard !task.isSoftDeleted else { return }
        task.group = group
        let targetTasks = context.fetchActiveTasks().filter { item in
            guard item.uuid != task.uuid else { return false }
            if let group {
                return item.group?.uuid == group.uuid
            }
            return item.group == nil
        }
        task.sortOrder = (targetTasks.map(\.sortOrder).max() ?? -1) + 1
        task.updatedAt = now()
        onChange(context)
    }

    /// Возврат из «Удалённых».
    func restore(_ task: TaskItem) {
        task.isSoftDeleted = false
        task.deletedAt = nil
        task.updatedAt = now()
        try? context.save()
        onChange(context)
    }

    /// Окончательное удаление. Удаляются только задачи, которые уже в корзине, —
    /// активную задачу так стереть нельзя, даже если её передали по ошибке.
    func permanentlyDelete(_ tasks: [TaskItem]) {
        let trashed = tasks.filter(\.isSoftDeleted)
        guard !trashed.isEmpty else { return }
        for task in trashed {
            context.delete(task)
        }
        try? context.save()
        onChange(context)
    }
}
