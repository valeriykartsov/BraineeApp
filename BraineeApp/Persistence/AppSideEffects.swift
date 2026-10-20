//
//  AppSideEffects.swift
//  BraineeApp
//
//  Что происходит после любого изменения данных (roadmap SD-4): сохранение хранилища SwiftData,
//  снимок для виджета и пересчёт уведомлений. JSON — только автобэкап при уходе в фон (AutoBackup).

import Foundation
import SwiftData
import SwiftUI

@MainActor
enum AppSideEffects {
    /// `refreshNotifications: false` — только для тестов: пересчёт уведомлений идёт асинхронно
    /// с моделями контекста и пережил бы тестовый контейнер.
    static func didChange(in context: ModelContext, refreshNotifications: Bool = true) {
        do {
            try context.save()
        } catch {
            print("AppSideEffects: SwiftData save failed: \(error)")
        }
        let tasks = context.fetchActiveTasks()
        let habits = context.fetchHabits()
        WidgetSnapshotBuilder.publish(tasks: tasks, habits: habits)
        guard refreshNotifications else { return }
        Task {
            await AppNotifications.refresh(tasks: tasks, habits: habits)
        }
    }
}

extension ModelContext {
    /// Вызывают сервисы Domain/ после любого изменения задач, групп, тегов, привычек и профиля.
    @MainActor
    func didChange() {
        AppSideEffects.didChange(in: self)
    }
}

/// При уходе в фон: сохранить данные и сделать автобэкап JSON, если пора (D-04).
struct BackgroundSaveModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                // Только background: inactive (шторка/переключатель приложений) срабатывает слишком часто.
                guard phase == .background else { return }
                modelContext.didChange()
                do {
                    try AutoBackup().performIfDue(context: modelContext)
                } catch {
                    print("AutoBackup failed: \(error)")
                }
            }
    }
}

extension View {
    func saveOnBackground() -> some View {
        modifier(BackgroundSaveModifier())
    }
}
