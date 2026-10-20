//
//  CalendarExport.swift
//  BraineeApp
//
//  Точка входа экспорта в Календарь (CAL-2): настройка вкл/выкл, общий EventKit и запуск сверки
//  после изменений данных (AppSideEffects) и при возврате в приложение.

import Foundation
import SwiftData

@MainActor
enum CalendarExport {
    nonisolated static let enabledKey = "calendarExportEnabled"
    nonisolated static let lastErrorKey = "calendarExportLastError"
    nonisolated static let lastSyncKey = "calendarExportLastSync"

    /// Один EKEventStore на приложение (Apple советует не создавать его часто).
    static let store = EventKitCalendarStore()

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var lastError: String? {
        UserDefaults.standard.string(forKey: lastErrorKey)
    }

    static var lastSync: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    /// «BraineeApp · iCloud» или nil, если календаря ещё нет (или его удалили).
    static var calendarSummary: String? {
        CalendarLinksFile.standard().load().calendarID.flatMap(store.calendarSummary(id:))
    }

    static func service() -> CalendarExportService {
        CalendarExportService(store: store, links: CalendarLinksFile.standard())
    }

    /// После любого изменения данных и при возврате в приложение. Выключено — ничего не делает.
    /// Ошибка не мешает работе приложения: она показывается в настройках экспорта.
    static func syncIfEnabled(tasks: [TaskItem]) {
        guard isEnabled else { return }
        run { try service().sync(tasks: tasks) }
    }

    static func syncIfEnabled(context: ModelContext) {
        guard isEnabled else { return }
        syncIfEnabled(tasks: context.fetchActiveTasks())
    }

    /// Включение в настройках: запрос полного доступа, затем сразу экспорт всех активных задач с датой.
    /// false — доступа нет, экспорт остаётся выключенным.
    static func enable(context: ModelContext) async -> Bool {
        if store.access != .fullAccess {
            _ = await store.requestAccess()
        }
        guard store.access == .fullAccess else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            return false
        }
        UserDefaults.standard.set(true, forKey: enabledKey)
        syncIfEnabled(context: context)
        return true
    }

    /// Выключение только прекращает обновление: календарь и события остаются (D-22).
    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: lastErrorKey)
    }

    private static func run(_ body: () throws -> CalendarExportService.Summary) {
        do {
            _ = try body()
            UserDefaults.standard.removeObject(forKey: lastErrorKey)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: lastErrorKey)
            print("CalendarExport: \(error)")
        }
    }
}
