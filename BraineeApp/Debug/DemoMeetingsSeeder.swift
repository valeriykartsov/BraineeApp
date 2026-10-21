//
//  DemoMeetingsSeeder.swift
//  BraineeApp
//
//  Только отладочная сборка, аргумент запуска `-SeedDemoMeetings`: для проверки блока
//  «Встречи» (D-37) создаёт календарь «Демо-встречи» с событиями на сегодня.
//  Нужен полный доступ к Календарю (в симуляторе — `xcrun simctl privacy … grant calendar`).
//  Если календарь «Демо-встречи» уже есть — ничего не делает. Другие календари не трогает.

#if DEBUG
import EventKit
import Foundation

@MainActor
enum DemoMeetingsSeeder {
    static let launchArgument = "-SeedDemoMeetings"
    static let calendarTitle = "Демо-встречи"

    static func seedIfRequested(now: Date = .now, calendar: Calendar = .current) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        let store = CalendarExport.store.store
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              !store.calendars(for: .event).contains(where: { $0.title == calendarTitle }),
              let source = store.sources.first(where: { $0.sourceType == .local })
                ?? store.defaultCalendarForNewEvents?.source
        else { return }

        let demo = EKCalendar(for: .event, eventStore: store)
        demo.title = calendarTitle
        demo.source = source

        let today = calendar.startOfDay(for: now)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let events: [(String, Date, Date, Bool)] = [
            ("Отпуск коллеги", today, at(1, 0), true),
            ("Планёрка", at(0, 9), at(0, 9, 30), false),
            ("Встреча с клиентом", at(0, 13), at(0, 14, 30), false),
            ("Ночной релиз", at(-1, 23), at(0, 1), false),
            ("Тренировка", at(0, 19), at(0, 20), false)
        ]

        do {
            try store.saveCalendar(demo, commit: false)
            for (title, start, end, allDay) in events {
                let event = EKEvent(eventStore: store)
                event.calendar = demo
                event.title = title
                event.startDate = start
                event.endDate = end
                event.isAllDay = allDay
                try store.save(event, span: .thisEvent, commit: false)
            }
            try store.commit()
        } catch {
            print("DemoMeetingsSeeder: \(error)")
        }
    }
}
#endif
