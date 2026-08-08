//
//  HabitsProgressWidget.swift
//  BraineeAppWidget
//
//  Маленький виджет: прогресс привычек за сегодня.

import WidgetKit
import SwiftUI

struct HabitsProgressWidget: Widget {
    let kind = "HabitsProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            HabitsProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Привычки")
        .description("Прогресс отметок привычек за сегодня.")
        .supportedFamilies([.systemSmall])
    }
}
