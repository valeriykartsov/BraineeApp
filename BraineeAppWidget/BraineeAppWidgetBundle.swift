//
//  BraineeAppWidgetBundle.swift
//  BraineeAppWidget
//
//  Точка входа расширения: четыре виджета BraineeApp.

import WidgetKit
import SwiftUI

@main
struct BraineeAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        HabitsProgressWidget()
        TasksDashboardWidget()
        TasksHabitsWidget()
    }
}
