//
//  CalendarExportService.swift
//  BraineeApp
//
//  Односторонний экспорт задач в календарь «BraineeApp» (roadmap CAL-2, D-05, D-06, D-22).
//  Не реагирует на каждую операцию отдельно, а сверяет весь список: «какие события должны быть» ↔
//  «какие есть». Поэтому одинаково обрабатываются создание, правка, выполнение, корзина,
//  восстановление из бэкапа и окончательное удаление. Неизменённые события не переписываются.

import Foundation

@MainActor
struct CalendarExportService {
    struct Summary: Equatable {
        var created = 0
        var updated = 0
        var removed = 0
        /// Календарь создан заново (первое включение или пользователь удалил прежний).
        var calendarCreated = false
    }

    let store: CalendarEventStore
    let links: CalendarLinksStoring
    var calendar: Calendar = .current
    var now: () -> Date = { .now }

    /// Сверить календарь с задачами. `tasks` — все задачи (удалённые и выполненные просто не попадут в календарь).
    @discardableResult
    func sync(tasks: [TaskItem]) throws -> Summary {
        let drafts = Dictionary(
            tasks.compactMap { task in CalendarEventRules.draft(for: task, calendar: calendar).map { (task.uuid.uuidString, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        return try sync(drafts: drafts)
    }

    /// То же для готовых черновиков: uuid задачи → событие.
    @discardableResult
    func sync(drafts: [String: CalendarEventDraft]) throws -> Summary {
        guard store.access == .fullAccess else { throw CalendarExportError.noAccess }
        var summary = Summary()
        var state = links.load()

        // 1. Календарь: сохранённый → существующий с таким названием (переустановка) → новый.
        //    Создаётся только здесь и один раз за проход — двойное нажатие дублей не даёт (CAL-1).
        if state.calendarID.flatMap(store.calendarSummary(id:)) == nil {
            let calendarID = try store.writableCalendarIDs(titled: CalendarEventRules.calendarTitle).first
                ?? createCalendar(&summary)
            state = CalendarLinks(calendarID: calendarID, events: [:])
        }
        guard let calendarID = state.calendarID else { return summary }

        // 2. События по сохранённым связям.
        var found: [String: CalendarEventRecord] = [:]
        for (uuid, eventID) in state.events {
            if let record = store.event(id: eventID, calendarID: calendarID) {
                found[uuid] = record
            }
        }

        // 3. Чего-то не нашли по id — ищем по меткам во всём календаре. Заодно убираем дубли
        //    и события задач, которых больше нет в списке (например, после восстановления из бэкапа).
        let missing = drafts.keys.contains { found[$0] == nil }
        if missing || found.count != state.events.count {
            var byTask: [String: [CalendarEventRecord]] = [:]
            for record in store.events(calendarID: calendarID, from: scanStart(drafts), to: scanEnd(drafts)) {
                guard let uuid = CalendarEventRules.taskUUID(from: record.draft.url)?.uuidString else { continue }
                byTask[uuid, default: []].append(record)
            }
            for (uuid, records) in byTask {
                // Одно событие на задачу оставляем (лишнее, если задача не экспортируется, уберёт шаг 5).
                guard let keep = found[uuid] ?? records.first else { continue }
                found[uuid] = keep
                for record in records where record.id != keep.id {
                    try store.removeEvent(id: record.id)
                    summary.removed += 1
                }
            }
        }

        // 4. Создать или обновить нужные события.
        var newEvents: [String: String] = [:]
        for (uuid, draft) in drafts {
            if let record = found[uuid] {
                if CalendarEventRules.needsUpdate(record.draft, to: draft, calendar: calendar) {
                    newEvents[uuid] = try store.save(draft, eventID: record.id, calendarID: calendarID)
                    summary.updated += 1
                } else {
                    newEvents[uuid] = record.id
                }
            } else {
                newEvents[uuid] = try store.save(draft, eventID: nil, calendarID: calendarID)
                summary.created += 1
            }
        }

        // 5. Убрать события задач, которые больше не экспортируются (выполнены, удалены, без даты).
        for (uuid, record) in found where drafts[uuid] == nil {
            try store.removeEvent(id: record.id)
            summary.removed += 1
        }

        state.events = newEvents
        try links.save(state)
        return summary
    }

    private func createCalendar(_ summary: inout Summary) throws -> String {
        summary.calendarCreated = true
        return try store.createCalendar(title: CalendarEventRules.calendarTitle)
    }

    /// Период поиска по меткам: год назад … год вперёд и все даты задач.
    private func scanStart(_ drafts: [String: CalendarEventDraft]) -> Date {
        let earliest = drafts.values.map(\.start).min() ?? now()
        return min(earliest, now()).addingTimeInterval(-366 * 86_400)
    }

    private func scanEnd(_ drafts: [String: CalendarEventDraft]) -> Date {
        let latest = drafts.values.map(\.end).max() ?? now()
        return max(latest, now()).addingTimeInterval(366 * 86_400)
    }
}
