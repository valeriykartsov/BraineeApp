//
//  TasksHabitsWidget.swift
//  BraineeAppWidget
//
//  Большой виджет: задачи и привычки.

import WidgetKit
import SwiftUI

struct TasksHabitsWidget: Widget {
    let kind = "TasksHabitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            TasksHabitsWidgetView(entry: entry)
        }
        .configurationDisplayName("Задачи и привычки")
        .description("Задачи, сводка и привычки на одном виджете.")
        .supportedFamilies([.systemLarge])
    }
}
