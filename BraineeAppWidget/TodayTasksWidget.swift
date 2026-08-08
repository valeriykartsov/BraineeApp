//
//  TodayTasksWidget.swift
//  BraineeAppWidget
//
//  Маленький виджет: до 3 приоритетных задач на сегодня.

import WidgetKit
import SwiftUI

struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Задачи сегодня")
        .description("Три самые приоритетные задачи на сегодня.")
        .supportedFamilies([.systemSmall])
    }
}
