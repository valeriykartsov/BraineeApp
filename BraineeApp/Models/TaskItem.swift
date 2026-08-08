//
//  TaskItem.swift
//  BraineeApp
//
//  Модель задачи: название, дедлайн, напоминания, приоритет, статус, описание, группа, теги.

import Foundation
import SwiftData

@Model
final class TaskItem {
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
            statusRaw = newValue.rawValue
            isCompleted = newValue == .done
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
        guard let deadline else { return false }
        return Calendar.current.isDateInToday(deadline)
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
