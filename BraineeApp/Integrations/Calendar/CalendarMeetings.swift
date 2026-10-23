//
//  CalendarMeetings.swift
//  BraineeApp
//
//  Встречи из Календаря iPhone под задачами дня (D-37): только чтение, без сохранения.
//  Правила дня (`CalendarMeetingRules`) — чистые функции, чтобы проверять их тестами
//  без настоящего Календаря; EventKit — только в `EventKitCalendarStore.meetings`.

import EventKit
import Foundation

/// Событие из Календаря в том виде, в каком его показывает приложение.
struct CalendarMeeting: Equatable {
    /// У повторяющихся встреч `eventIdentifier` общий — к id добавлено время начала.
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
}

/// Встреча, разложенная на выбранный день.
struct DayMeeting: Equatable, Identifiable {
    enum Timing: Equatable {
        /// Событие «весь день» или встреча, занимающая весь день целиком.
        case allDay
        /// Начинается в этот день.
        case starts(Date)
        /// Началась раньше и заканчивается в этот день.
        case continuesUntil(Date)
    }

    let meeting: CalendarMeeting
    let timing: Timing

    var id: String { meeting.id }
}

/// Встреча так, как её видит пользователь: на экране и в тексте «Поделиться» (D-37, D-43) — из одного места.
struct DayMeetingText: Equatable {
    /// «09:00», «Весь день», «до 11:00».
    let time: String
    /// «1 ч 30 мин»; у встречи на весь день нет.
    let duration: String?
    /// «Без названия», если у события нет названия.
    let title: String
    let calendarTitle: String

    init(_ item: DayMeeting, calendar: Calendar = .current) {
        let meeting = item.meeting
        switch item.timing {
        case .allDay:
            time = "Весь день"
            duration = nil
        case .starts(let start):
            time = CalendarMeetingRules.timeText(start, calendar: calendar)
            duration = CalendarMeetingRules.durationText(from: meeting.start, to: meeting.end)
        case .continuesUntil(let end):
            time = "до \(CalendarMeetingRules.timeText(end, calendar: calendar))"
            duration = CalendarMeetingRules.durationText(from: meeting.start, to: meeting.end)
        }
        title = meeting.title.isEmpty ? "Без названия" : meeting.title
        calendarTitle = meeting.calendarTitle
    }

    /// Строка текста «Поделиться»: «09:30 · 30 мин — Планёрка (Работа)», «Весь день — Отпуск (Семья)».
    var shareLine: String {
        let when = [time, duration].compactMap { $0 }.joined(separator: " · ")
        let what = calendarTitle.isEmpty ? title : "\(title) (\(calendarTitle))"
        return "\(when) — \(what)"
    }
}

enum CalendarMeetingRules {
    /// Встречи на день `day`: без календаря «BraineeApp» (это сами задачи, D-37);
    /// сначала «весь день», дальше по времени начала, при равенстве — по названию.
    static func meetings(
        on day: Date,
        from events: [CalendarMeeting],
        calendar: Calendar = .current
    ) -> [DayMeeting] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let items: [DayMeeting] = events.compactMap { event in
            guard event.calendarTitle != CalendarEventRules.calendarTitle,
                  event.start < dayEnd,
                  event.end > dayStart || (event.end == event.start && event.start >= dayStart)
            else { return nil }

            let timing: DayMeeting.Timing
            if event.isAllDay || (event.start <= dayStart && event.end >= dayEnd) {
                timing = .allDay
            } else if event.start >= dayStart {
                timing = .starts(event.start)
            } else {
                timing = .continuesUntil(event.end)
            }
            return DayMeeting(meeting: event, timing: timing)
        }

        return items.sorted { lhs, rhs in
            let left = sortKey(lhs)
            let right = sortKey(rhs)
            if left != right { return left < right }
            return lhs.meeting.title.localizedCaseInsensitiveCompare(rhs.meeting.title) == .orderedAscending
        }
    }

    /// «Весь день» первыми; «до ЧЧ:ММ» — по времени окончания (они идут с начала дня).
    private static func sortKey(_ item: DayMeeting) -> Date {
        switch item.timing {
        case .allDay: return .distantPast
        case .starts(let date): return date
        case .continuesUntil(let date): return date
        }
    }

    /// Время для левой колонки: «09:00» в поясе календаря.
    static func timeText(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Продолжительность для левой колонки: «30 мин», «1 ч», «1 ч 30 мин», «2 д».
    static func durationText(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
        if minutes >= 24 * 60 {
            let days = Int((Double(minutes) / (24 * 60)).rounded())
            return "\(days) д"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) мин"
        case (_, 0): return "\(hours) ч"
        default: return "\(hours) ч \(rest) мин"
        }
    }
}

/// Настройка «Встречи из Календаря» и чтение встреч дня (D-37).
@MainActor
enum CalendarMeetings {
    nonisolated static let enabledKey = "calendarMeetingsEnabled"
    /// Календарь изменился (в том числе в другом приложении) — встречи дня надо перечитать.
    nonisolated static let changedNotification: Notification.Name = .EKEventStoreChanged

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Показывать блок можно только с включённой настройкой и полным доступом.
    static var isAvailable: Bool {
        isEnabled && CalendarExport.store.access == .fullAccess
    }

    /// Включение: запрос полного доступа (общий EventKit с экспортом). false — доступа нет, настройка выключена.
    static func enable() async -> Bool {
        let store = CalendarExport.store
        if store.access != .fullAccess {
            _ = await store.requestAccess()
        }
        let granted = store.access == .fullAccess
        UserDefaults.standard.set(granted, forKey: enabledKey)
        return granted
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
    }

    /// События за промежуток для «Итогов» (D-44); `nil`, если настройка выключена или доступа нет.
    static func events(from start: Date, to end: Date) -> [CalendarMeeting]? {
        guard isAvailable else { return nil }
        return CalendarExport.store.meetings(from: start, to: end)
    }

    /// Встречи выбранного дня; пусто, если настройка выключена или доступа нет.
    static func meetings(on day: Date, calendar: Calendar = .current) -> [DayMeeting] {
        guard isAvailable else { return [] }
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let events = CalendarExport.store.meetings(from: dayStart, to: dayEnd)
        return CalendarMeetingRules.meetings(on: day, from: events, calendar: calendar)
    }
}

extension EventKitCalendarStore {
    /// События всех календарей, пересекающие промежуток (повторы EventKit разворачивает сам).
    func meetings(from start: Date, to end: Date) -> [CalendarMeeting] {
        guard access == .fullAccess, start < end else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard let id = event.eventIdentifier, let eventStart = event.startDate, let eventEnd = event.endDate else {
                return nil
            }
            return CalendarMeeting(
                id: "\(id)|\(eventStart.timeIntervalSinceReferenceDate)",
                title: event.title ?? "",
                start: eventStart,
                end: eventEnd,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar?.title ?? ""
            )
        }
    }
}
