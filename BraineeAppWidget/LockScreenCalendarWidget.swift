//
//  LockScreenCalendarWidget.swift
//  BraineeAppWidget
//
//  Экран блокировки 1×1: день недели, число и задачи на сегодня (п. 11).

import WidgetKit
import SwiftUI

struct LockScreenCalendarWidget: Widget {
    let kind = "LockScreenCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BraineeWidgetProvider()) { entry in
            LockScreenCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Календарь")
        .description("Дата и сколько задач на сегодня осталось.")
        .supportedFamilies([.accessoryCircular])
    }
}
