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
    /// Журнал сессии (п. 16); в тестах — свой экземпляр.
    var log: SessionLog = .shared

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
            sortOrder: nextOrder,
            durationMinutes: TaskDuration.stored(form.durationMinutes, hasDeadlineTime: form.hasDeadlineTime && form.deadline != nil)
        )
        context.insert(task)
        // Теги — после insert: связь «многие ко многим», заданная в init до вставки,
        // становится видна SwiftData только после save(); так она видна сразу.
        task.tags = form.selectedTags
        if let subtasks = form.subtasks {
            applySubtasks(subtasks, to: task)
        }
        log.add(.task, "Задача создана", subject: task.title)
        onChange(context)
        return task
    }

    func update(_ task: TaskItem, from form: TaskFormData) {
        let before = TaskLogFields(task)
        task.title = form.title
        task.deadline = form.deadline
        task.hasDeadlineTime = form.hasDeadlineTime && form.deadline != nil
        // Длительность только у задачи со временем: убрали время или дату — сброс (D-40).
        task.durationMinutes = TaskDuration.stored(form.durationMinutes, hasDeadlineTime: task.hasDeadlineTime)
        task.reminderOffsets = form.reminderOffsets
        task.priority = form.priority
        task.status = form.status
        task.category = .tasks
        task.taskDetails = form.taskDetails
        task.tags = form.selectedTags
        if let subtasks = form.subtasks {
            applySubtasks(subtasks, to: task)
        }
        task.updatedAt = now()
        // Сохранение формы без правок в журнал не пишется.
        let changes = TaskLogFields.changes(from: before, to: TaskLogFields(task))
        if !changes.isEmpty {
            log.add(.task, "Задача изменена", subject: task.title, changes: changes)
        }
        onChange(context)
    }

    /// Пометка в журнале сессии у действий кнопками уведомления (D-46 п. 7).
    static let fromNotificationNote = " (из уведомления)"

    /// Чекбокс: выполненная уходит в конец своей группы (или во «Входящих»),
    /// снятие отметки — в конец незакрытых той же группы.
    func toggleCompletion(_ task: TaskItem, fromNotification: Bool = false) {
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
        let title = task.isCompleted ? "Задача выполнена" : "Отметка выполнения снята"
        log.add(.task, title + (fromNotification ? Self.fromNotificationNote : ""), subject: task.title)
        onChange(context)
    }

    /// «На завтра» из уведомления (D-46 п. 4): срок — завтра от сегодняшней даты, время сохраняется,
    /// задача без времени остаётся без времени; длительность и пресеты напоминаний не меняются.
    func postponeToTomorrow(_ task: TaskItem, calendar: Calendar = .current, fromNotification: Bool = false) {
        let current = now()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current)) else { return }
        var newDeadline = tomorrow
        if task.hasDeadlineTime, let deadline = task.deadline {
            let time = calendar.dateComponents([.hour, .minute], from: deadline)
            newDeadline = calendar.date(
                bySettingHour: time.hour ?? 0,
                minute: time.minute ?? 0,
                second: 0,
                of: tomorrow
            ) ?? tomorrow
        }
        let before = TaskLogFields(task)
        task.deadline = newDeadline
        task.hasDeadlineTime = task.hasDeadlineTime && before.deadline != nil
        task.updatedAt = current
        let changes = TaskLogFields.changes(from: before, to: TaskLogFields(task), timeZone: calendar.timeZone)
        if !changes.isEmpty {
            log.add(
                .task,
                "Задача изменена" + (fromNotification ? Self.fromNotificationNote : ""),
                subject: task.title,
                changes: changes
            )
        }
        onChange(context)
    }

    /// Смена статуса из канбана (порядок не меняется).
    func setStatus(_ task: TaskItem, _ status: TaskStatus) {
        if let change = SessionLogDiff.line("Статус", task.status.title, status.title) {
            log.add(.task, "Задача изменена", subject: task.title, changes: [change])
        }
        task.status = status
        task.updatedAt = now()
        onChange(context)
    }

    /// В «Удалённые»: задача остаётся в базе, окончательное удаление — только из корзины.
    func softDelete(_ task: TaskItem) {
        task.isSoftDeleted = true
        task.deletedAt = now()
        task.updatedAt = now()
        log.add(.task, "Задача удалена в корзину", subject: task.title)
        try? context.save()
        onChange(context)
    }

    /// Перенос в группу (drag-and-drop) или во «Входящие» (`group == nil`): в конец целевой группы.
    /// Задачи из корзины не переносятся.
    func move(_ task: TaskItem, to group: TaskGroup?) {
        guard !task.isSoftDeleted else { return }
        // Перестановка внутри той же папки в журнал не пишется — только смена папки.
        if let change = SessionLogDiff.line("Папка", Self.folderName(task.group), Self.folderName(group)) {
            log.add(.task, "Задача изменена", subject: task.title, changes: [change])
        }
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
        log.add(.task, "Задача восстановлена из корзины", subject: task.title)
        try? context.save()
        onChange(context)
    }

    /// Окончательное удаление. Удаляются только задачи, которые уже в корзине, —
    /// активную задачу так стереть нельзя, даже если её передали по ошибке.
    func permanentlyDelete(_ tasks: [TaskItem]) {
        let trashed = tasks.filter(\.isSoftDeleted)
        guard !trashed.isEmpty else { return }
        log.add(
            .task,
            "Удалено из корзины навсегда",
            subject: trashed.count == 1 ? trashed[0].title : "Задач: \(trashed.count)"
        )
        for task in trashed {
            context.delete(task)
        }
        try? context.save()
        onChange(context)
    }

    /// Приводит подзадачи задачи к списку формы (D-41): по uuid обновляет, новые добавляет,
    /// убранные удаляет; порядок — порядок в списке. Отметка всех подзадач задачу не закрывает.
    private func applySubtasks(_ drafts: [SubtaskDraft], to task: TaskItem) {
        let wanted = TaskSubtaskRules.normalized(drafts)
        let wantedIDs = Set(wanted.map(\.id))
        for subtask in task.subtasks where !wantedIDs.contains(subtask.uuid) {
            context.delete(subtask)
        }
        let existing = Dictionary(
            task.subtasks.filter { wantedIDs.contains($0.uuid) }.map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        task.subtasks = wanted.enumerated().map { index, draft in
            let subtask = existing[draft.id] ?? TaskSubtask(uuid: draft.id, title: draft.title)
            if existing[draft.id] == nil {
                context.insert(subtask)
            }
            subtask.title = draft.title
            subtask.isDone = draft.isDone
            subtask.sortOrder = index
            return subtask
        }
    }

    private static func folderName(_ group: TaskGroup?) -> String {
        group.map { SessionLogDiff.quoted($0.name) } ?? "Входящие"
    }
}
