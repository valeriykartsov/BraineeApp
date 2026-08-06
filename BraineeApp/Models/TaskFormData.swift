//
//  TaskFormData.swift
//  BraineeApp
//

import Foundation

struct TaskFormData {
    var title: String
    var deadline: Date?
    var priority: TaskPriority
    var category: TaskCategory
    var taskDetails: String
    var selectedTags: [TaskTag]
}
