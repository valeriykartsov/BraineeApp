//
//  TasksDashboardWidget.swift
//  BraineeAppWidget
//
//  Средний виджет: задачи и мини-дашборд.

import WidgetKit
import SwiftUI

struct TasksDashboardWidget: Widget {
    let kind = "TasksDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            TasksDashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Задачи и дашборд")
        .description("Список задач и краткая сводка.")
        .supportedFamilies([.systemMedium])
    }
}
