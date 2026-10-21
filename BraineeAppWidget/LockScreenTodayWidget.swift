//
//  LockScreenTodayWidget.swift
//  BraineeAppWidget
//
//  Экран блокировки 2×1: прогресс привычек и задач за сегодня (п. 11).

import WidgetKit
import SwiftUI

struct LockScreenTodayWidget: Widget {
    let kind = "LockScreenTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            LockScreenTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Сегодня")
        .description("Прогресс привычек и задач за сегодня.")
        .supportedFamilies([.accessoryRectangular])
    }
}
