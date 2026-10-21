//
//  CalendarEventStore.swift
//  BraineeApp
//
//  Доступ к календарю через EventKit (CAL-2). Протокол нужен, чтобы логику экспорта
//  проверять тестами на подставном хранилище, без настоящего Календаря.

import EventKit
import Foundation

/// Событие, прочитанное из календаря.
struct CalendarEventRecord: Equatable {
    let id: String
    let draft: CalendarEventDraft
}

enum CalendarAccess: Equatable {
    case notDetermined
    case denied
    /// Только запись: найти своё событие для обновления нельзя, экспорт не работает.
    case writeOnly
    case fullAccess
}

enum CalendarExportError: LocalizedError, Equatable {
    case noAccess
    /// Нет ни iCloud, ни локального источника календарей (D-05).
    case noCalendarSource
    case eventKit(String)

    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "Нет полного доступа к Календарю."
        case .noCalendarSource:
            return "На устройстве нет календарей iCloud или «На iPhone» — создать календарь «BraineeApp» негде."
        case .eventKit(let message):
            return "Календарь: \(message)"
        }
    }
}

@MainActor
protocol CalendarEventStore: AnyObject {
    var access: CalendarAccess { get }
    func requestAccess() async -> Bool

    /// Описание календаря для экрана настроек («BraineeApp · iCloud»); nil — календаря нет.
    func calendarSummary(id: String) -> String?
    /// Календари с этим названием, в которые можно писать (iCloud первым).
    func writableCalendarIDs(titled title: String) -> [String]
    /// Новый календарь: в iCloud, иначе в локальном источнике (D-05).
    func createCalendar(title: String) throws -> String

    /// Событие по id — только если оно лежит в календаре `calendarID`.
    func event(id: String, calendarID: String) -> CalendarEventRecord?
    func events(calendarID: String, from: Date, to: Date) -> [CalendarEventRecord]
    /// Создаёт (eventID == nil) или обновляет событие, возвращает его id.
    func save(_ draft: CalendarEventDraft, eventID: String?, calendarID: String) throws -> String
    func removeEvent(id: String) throws
}

@MainActor
final class EventKitCalendarStore: CalendarEventStore {
    /// Не private: чтение встреч (`CalendarMeetings.swift`, D-37) использует тот же EKEventStore.
    let store = EKEventStore()

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func calendarSummary(id: String) -> String? {
        guard let calendar = store.calendar(withIdentifier: id) else { return nil }
        return "\(calendar.title) · \(calendar.source.title)"
    }

    func writableCalendarIDs(titled title: String) -> [String] {
        let matching = store.calendars(for: .event)
            .filter { $0.title == title && $0.allowsContentModifications }
        let iCloud = matching.filter { Self.isICloud($0.source) }
        let others = matching.filter { !Self.isICloud($0.source) }
        return (iCloud + others).map(\.calendarIdentifier)
    }

    func createCalendar(title: String) throws -> String {
        guard let source = store.sources.first(where: Self.isICloud)
            ?? store.sources.first(where: { $0.sourceType == .local })
        else { throw CalendarExportError.noCalendarSource }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = title
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
        } catch {
            throw CalendarExportError.eventKit(error.localizedDescription)
        }
        return calendar.calendarIdentifier
    }

    func event(id: String, calendarID: String) -> CalendarEventRecord? {
        guard let event = store.event(withIdentifier: id),
              event.calendar?.calendarIdentifier == calendarID
        else { return nil }
        return Self.record(event)
    }

    func events(calendarID: String, from: Date, to: Date) -> [CalendarEventRecord] {
        guard let calendar = store.calendar(withIdentifier: calendarID), from < to else { return [] }
        // EventKit ищет не больше чем в 4-летнем окне — длинный период делим на части.
        var result: [String: CalendarEventRecord] = [:]
        var windowStart = from
        while windowStart < to {
            let windowEnd = min(to, windowStart.addingTimeInterval(3 * 365 * 86_400))
            let predicate = store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: [calendar])
            for event in store.events(matching: predicate) {
                guard let record = Self.record(event) else { continue }
                result[record.id] = record
            }
            windowStart = windowEnd
        }
        return Array(result.values)
    }

    func save(_ draft: CalendarEventDraft, eventID: String?, calendarID: String) throws -> String {
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw CalendarExportError.eventKit("календарь не найден")
        }
        let event = eventID.flatMap { store.event(withIdentifier: $0) } ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = draft.title
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.end
        event.notes = draft.notes
        event.url = draft.url
        // Без напоминаний: уведомления о задачах присылает само приложение (D-22).
        event.alarms = nil
        // commit сразу: у нового события идентификатор надёжно есть только после записи
        // (так и проверено на устройстве в CAL-1).
        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarExportError.eventKit(error.localizedDescription)
        }
        guard let id = event.eventIdentifier else {
            throw CalendarExportError.eventKit("событие сохранено без идентификатора")
        }
        return id
    }

    func removeEvent(id: String) throws {
        guard let event = store.event(withIdentifier: id) else { return }
        do {
            try store.remove(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarExportError.eventKit(error.localizedDescription)
        }
    }

    private static func isICloud(_ source: EKSource) -> Bool {
        source.sourceType == .calDAV && source.title == "iCloud"
    }

    private static func record(_ event: EKEvent) -> CalendarEventRecord? {
        guard let id = event.eventIdentifier else { return nil }
        return CalendarEventRecord(
            id: id,
            draft: CalendarEventDraft(
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                notes: event.notes,
                url: event.url
            )
        )
    }
}
