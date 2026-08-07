//
//  TaskFormData.swift
//  BraineeApp
//
//  Временный набор полей формы создания/редактирования задачи перед сохранением.

import Foundation

struct TaskFormData {
    var title: String
    var deadline: Date?
    var priority: TaskPriority
    var category: TaskCategory
    var taskDetails: String
    var selectedTags: [TaskTag]
}
