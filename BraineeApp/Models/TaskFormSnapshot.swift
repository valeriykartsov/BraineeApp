//
//  TaskFormSnapshot.swift
//  BraineeApp
//
//  Снимок полей формы задачи для сравнения «есть несохранённые изменения».

import Foundation

struct TaskFormSnapshot: Equatable {
    var title: String
    var taskDetails: String
    var status: TaskStatus
    var priority: TaskPriority
    var hasDeadline: Bool
    var hasDeadlineTime: Bool
    /// Минуты с опорной даты — без секунд/наносекунд, чтобы не ловить ложный dirty.
    var deadlineMinute: Int?
    var reminderOffsets: [TaskReminderOffset]
    var selectedTagUUIDs: Set<UUID>
    /// Как сохранится в задаче (`TaskDuration.stored`): 30 мин и nil — одно и то же.
    var durationMinutes: Int?

    init(
        title: String = "",
        taskDetails: String = "",
        status: TaskStatus = .new,
        priority: TaskPriority = .medium,
        hasDeadline: Bool = false,
        hasDeadlineTime: Bool = false,
        deadline: Date? = nil,
        reminderOffsets: [TaskReminderOffset] = [],
        selectedTagUUIDs: Set<UUID> = [],
        durationMinutes: Int? = nil
    ) {
        self.title = title
        self.taskDetails = taskDetails
        self.status = status
        self.priority = priority
        self.hasDeadline = hasDeadline
        self.hasDeadlineTime = hasDeadline && hasDeadlineTime
        if hasDeadline, let deadline {
            self.deadlineMinute = Self.minuteStamp(deadline)
        } else {
            self.deadlineMinute = nil
        }
        self.reminderOffsets = hasDeadline
            ? TaskReminderOffset.normalizedList(reminderOffsets.map(\.rawValue))
            : []
        self.selectedTagUUIDs = selectedTagUUIDs
        self.durationMinutes = TaskDuration.stored(durationMinutes, hasDeadlineTime: self.hasDeadlineTime)
    }

    init(task: TaskItem) {
        self.init(
            title: task.title,
            taskDetails: task.taskDetails,
            status: task.status,
            priority: task.priority,
            hasDeadline: task.deadline != nil,
            hasDeadlineTime: task.hasDeadlineTime,
            deadline: task.deadline,
            reminderOffsets: task.reminderOffsets,
            selectedTagUUIDs: Set(task.tags.map(\.uuid)),
            durationMinutes: task.durationMinutes
        )
    }

    static func minuteStamp(_ date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        let h = comps.hour ?? 0
        let min = comps.minute ?? 0
        return ((((y * 100 + m) * 100 + d) * 100 + h) * 100) + min
    }
}
