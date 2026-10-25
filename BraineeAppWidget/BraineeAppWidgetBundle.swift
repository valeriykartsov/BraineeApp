//
//  BraineeAppWidgetBundle.swift
//  BraineeAppWidget
//
//  Точка входа расширения: четыре виджета экрана «Домой», два — экрана блокировки и Live Activity Помодоро.

import WidgetKit
import SwiftUI

@main
struct BraineeAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        HabitsProgressWidget()
        TasksDashboardWidget()
        TasksHabitsWidget()
        LockScreenCalendarWidget()
        LockScreenTodayWidget()
        PomodoroLiveActivity()
    }
}
