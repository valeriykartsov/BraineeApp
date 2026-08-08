//
//  TaskFormData.swift
//  BraineeApp
//
//  Временный набор полей формы создания/редактирования задачи перед сохранением.

import Foundation

struct TaskFormData {
    var title: String
    var deadline: Date?
    var hasDeadlineTime: Bool
    var reminderOffsets: [TaskReminderOffset]
    var priority: TaskPriority
    var status: TaskStatus
    var taskDetails: String
    var selectedTags: [TaskTag]
}
