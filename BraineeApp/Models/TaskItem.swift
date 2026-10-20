//
//  TaskItem.swift
//  BraineeApp
//
//  Модель задачи: название, дедлайн, напоминания, приоритет, статус, описание, группа, теги.

import Foundation
import SwiftData

@Model
final class TaskItem {
    /// Один uuid — одна запись: повторная вставка обновляет существующую (upsert), а не создаёт дубль (D-17).
    #Unique<TaskItem>([\.uuid])

    var title: String
    var isCompleted: Bool
    var deadline: Date?
    /// Показывать время дедлайна (если false — только дата).
    var hasDeadlineTime: Bool
    /// До 3 пресетов напоминаний (как в Calendar), rawValue TaskReminderOffset.
    var reminderOffsetsRaw: [String]
    var priorityRaw: Int
    var categoryRaw: String
    var statusRaw: String
    var createdAt: Date
    var taskDetails: String
    var sortOrder: Int
    var uuid: UUID
    /// Мягкое удаление (в «Удалённые»). Нельзя называть `isDeleted` —
    /// у SwiftData уже есть одноимённое системное свойство, и флаг не сохранялся в JSON.
    var isSoftDeleted: Bool
    var deletedAt: Date?
    /// Время последнего изменения (для синхронизации). Проставляют сервисы Domain/.
    var updatedAt: Date
    /// Когда задача стала «Готово»; nil — не выполнена или дата неизвестна (старые данные, D-03).
    var completedAt: Date?

    var group: TaskGroup?

    @Relationship
    var tags: [TaskTag]

    init(
        title: String,
        isCompleted: Bool = false,
        deadline: Date? = nil,
        hasDeadlineTime: Bool = false,
        reminderOffsets: [TaskReminderOffset] = [],
        priority: TaskPriority = .medium,
        category: TaskCategory = .tasks,
        status: TaskStatus? = nil,
        createdAt: Date = .now,
        taskDetails: String = "",
        sortOrder: Int = 0,
        uuid: UUID = UUID(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil,
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        group: TaskGroup? = nil,
        tags: [TaskTag] = []
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.hasDeadlineTime = hasDeadlineTime && deadline != nil
        self.reminderOffsetsRaw = deadline == nil
            ? []
            : TaskReminderOffset.encodeList(reminderOffsets)
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        let resolved = status ?? TaskStatus.fromCompletion(isCompleted)
        self.statusRaw = resolved.rawValue
        self.isCompleted = resolved == .done
        self.createdAt = createdAt
        self.taskDetails = taskDetails
        self.sortOrder = sortOrder
        self.uuid = uuid
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = resolved == .done ? completedAt : nil
        self.group = group
        self.tags = tags
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .tasks }
        set { categoryRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? TaskStatus.fromCompletion(isCompleted) }
        set {
            let wasDone = statusRaw == TaskStatus.done.rawValue
            statusRaw = newValue.rawValue
            isCompleted = newValue == .done
            // Дата закрытия: ставится при переходе в «Готово», сбрасывается при выходе из него.
            if newValue == .done {
                if !wasDone { completedAt = .now }
            } else {
                completedAt = nil
            }
        }
    }

    var reminderOffsets: [TaskReminderOffset] {
        get { TaskReminderOffset.normalizedList(reminderOffsetsRaw) }
        set {
            reminderOffsetsRaw = deadline == nil
                ? []
                : TaskReminderOffset.encodeList(newValue)
        }
    }

    var hasReminder: Bool { !reminderOffsets.isEmpty }

    /// Чекбокс: вкл → Готово, выкл → Новая.
    func applyCompletionToggle() {
        if isCompleted || status == .done {
            status = .new
        } else {
            status = .done
        }
    }

    /// Просрочена: по дате+времени (если время задано) или только по календарному дню.
    var isOverdue: Bool {
        isOverdue(at: .now)
    }

    func isOverdue(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let deadline, !isCompleted else { return false }
        if hasDeadlineTime {
            return deadline < now
        }
        return calendar.startOfDay(for: deadline) < calendar.startOfDay(for: now)
    }

    var isDueToday: Bool {
        isDue(on: .now)
    }

    /// Дедлайн приходится на тот же календарный день, что и `day` (в тестах — фиксированная дата).
    func isDue(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let deadline else { return false }
        return calendar.isDate(deadline, inSameDayAs: day)
    }

    /// Текст дедлайна для карточки: дата или дата + время.
    var deadlineDisplayText: String? {
        guard let deadline else { return nil }
        if hasDeadlineTime {
            return deadline.formatted(date: .abbreviated, time: .shortened)
        }
        return deadline.formatted(date: .abbreviated, time: .omitted)
    }

    /// Будущие моменты пушей по всем пресетам напоминаний.
    func reminderFireDates(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(offset: TaskReminderOffset, date: Date)] {
        guard let deadline, !isCompleted else { return [] }
        return reminderOffsets.compactMap { offset in
            guard let date = offset.fireDate(
                deadline: deadline,
                hasDeadlineTime: hasDeadlineTime,
                now: now,
                calendar: calendar
            ) else { return nil }
            return (offset, date)
        }
    }
}
