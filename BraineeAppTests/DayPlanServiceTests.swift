//
//  DayPlanServiceTests.swift
//  BraineeAppTests
//
//  LLM-4 «План дня» (D-32, D-33, D-44): какие задачи попадают в запрос и что о них уходит,
//  занятое время из встреч, сопоставление номеров из ответа с задачами, согласие на отправку. «Сейчас» — 21.10.2026 12:00.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct DayPlanServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private static let now = LLMTestSupport.now
    private static let calendar = LLMTestSupport.calendar

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        LLMTestSupport.date(2026, 10, day, hour, minute)
    }

    @discardableResult
    private func task(
        _ title: String,
        deadline: Date? = nil,
        time: Bool = false,
        priority: TaskPriority = .medium,
        done: Bool = false,
        deleted: Bool = false
    ) -> TaskItem {
        let item = TaskItem(
            title: title,
            deadline: deadline,
            hasDeadlineTime: time,
            priority: priority,
            status: done ? .done : .new,
            createdAt: date(1),
            isSoftDeleted: deleted
        )
        container.mainContext.insert(item)
        return item
    }

    private func select(_ tasks: [TaskItem]) -> [TaskItem] {
        DayPlanService.selectTasks(tasks, now: Self.now, calendar: Self.calendar)
    }

    // MARK: - Выбор задач

    // В план попадают только невыполненные задачи на сегодня и просроченные; удалённые, будущие и без срока — нет.
    @Test func выбор_сегодняИПросроченные() {
        let tasks = [
            task("Сегодня", deadline: date(21)),
            task("Сегодня вечером", deadline: date(21, 18), time: true),
            task("Вчера", deadline: date(20)),
            task("Завтра", deadline: date(22)),
            task("Без срока"),
            task("Выполнена сегодня", deadline: date(21), done: true),
            task("В корзине", deadline: date(21), deleted: true),
        ]
        #expect(Set(select(tasks).map(\.title)) == ["Сегодня", "Сегодня вечером", "Вчера"])
    }

    // Порядок: просроченные первыми, затем по приоритету, затем по сроку.
    @Test func выбор_порядок() {
        let tasks = [
            task("Средний 15:00", deadline: date(21, 15), time: true),
            task("Высокий", deadline: date(21), priority: .high),
            task("Просрочена низкий", deadline: date(19), priority: .low),
            task("Средний 13:00", deadline: date(21, 13), time: true),
        ]
        #expect(select(tasks).map(\.title) == ["Просрочена низкий", "Высокий", "Средний 13:00", "Средний 15:00"])
    }

    // Не больше 30 задач.
    @Test func выбор_неБольше30() {
        let tasks = (1...35).map { task("Задача \($0)", deadline: date(21)) }
        #expect(select(tasks).count == DayPlanService.maxTasks)
    }

    // MARK: - Что уходит наружу

    // D-32: номер, название, приоритет, время срока (только сегодняшнее), просрочка — без описаний, тегов, папок, uuid.
    @Test func запрос_толькоРазрешённыеПоля() throws {
        let group = TaskGroup(name: "Секретная папка")
        let tag = TaskTag(name: "Секретный тег")
        container.mainContext.insert(group)
        container.mainContext.insert(tag)
        let urgent = task("Позвонить в банк", deadline: date(21, 14, 30), time: true, priority: .high)
        urgent.taskDetails = "Номер договора 12345"
        urgent.group = group
        urgent.tags = [tag]
        let overdue = task("Отчёт", deadline: date(20, 9), time: true)

        let selected = select([urgent, overdue])
        let items = DayPlanService.inputItems(for: selected, now: Self.now, calendar: Self.calendar)
        #expect(items == [
            DayPlanInputItem(number: 1, title: "Отчёт", priority: .medium, time: nil, isOverdue: true),
            DayPlanInputItem(number: 2, title: "Позвонить в банк", priority: .high, time: "14:30", isOverdue: false),
        ])

        let request = try DayPlanService.makeRequest(items: items, now: Self.now, calendar: Self.calendar)
        let everything = request.messages.map(\.content).joined(separator: "\n")
        #expect(request.messages[0].content.hasPrefix(DayPlanService.modeMarker))
        #expect(request.messages[0].content.contains("Сейчас 12:00"))
        #expect(request.messages[1].content == "1. Отчёт; приоритет: средний; просрочена\n2. Позвонить в банк; приоритет: высокий; срок: 14:30")
        for secret in ["Номер договора", "Секретная папка", "Секретный тег", urgent.uuid.uuidString, overdue.uuid.uuidString] {
            #expect(!everything.contains(secret), "\(secret)")
        }
    }

    // Без задач запрос не строится.
    @Test func запрос_безЗадач_ошибка() {
        #expect(throws: DayPlanError.noTasks) {
            try DayPlanService.makeRequest(items: [], now: Self.now, calendar: Self.calendar)
        }
    }

    // MARK: - Разбор ответа

    // Номера сопоставляются с задачами; неизвестные и повторы отбрасываются; невошедшие — пометка.
    @Test func разбор_сопоставлениеНомеров() throws {
        let tasks = [task("Первая", deadline: date(21)), task("Вторая", deadline: date(21)), task("Третья", deadline: date(21))]
        let json = """
        {"summary": "Начните со второй.",
         "plan": [{"id": 2, "time": "9:05", "note": "Главное"}, {"id": 1, "time": null, "note": ""},
                  {"id": 7, "time": "10:00"}, {"id": "2", "time": "11:00"}, "мусор"]}
        """
        let plan = try DayPlanService.parse(json, tasks: tasks)
        #expect(plan.summary == "Начните со второй.")
        #expect(plan.items.map(\.title) == ["Вторая", "Первая"])
        #expect(plan.items.map(\.taskUUID) == [tasks[1].uuid, tasks[0].uuid])
        #expect(plan.items[0].suggestedTime == "09:05")
        #expect(plan.items[0].note == "Главное")
        #expect(plan.items[1].suggestedTime == nil)
        #expect(plan.notes.contains { $0.contains("неизвестным номером: 2") })
        #expect(plan.notes.contains { $0.contains("Не вошли в план задач: 1") })
    }

    // Неверное время не ломает пункт; номер строкой принимается.
    @Test func разбор_плохоеВремяИНомерСтрокой() throws {
        let tasks = [task("Одна", deadline: date(21))]
        let plan = try DayPlanService.parse(#"{"plan": [{"id": "1", "time": "25:99"}]}"#, tasks: tasks)
        #expect(plan.items.count == 1)
        #expect(plan.items[0].suggestedTime == nil)
        #expect(plan.summary.isEmpty)
    }

    // Не JSON или ни одного известного номера — ошибка.
    @Test func разбор_ошибки() {
        let tasks = [task("Одна", deadline: date(21))]
        #expect(throws: DayPlanError.invalidJSON) { try DayPlanService.parse("План: сначала одна", tasks: tasks) }
        #expect(throws: DayPlanError.emptyPlan) { try DayPlanService.parse(#"{"plan": [{"id": 5}]}"#, tasks: tasks) }
        #expect(throws: DayPlanError.emptyPlan) { try DayPlanService.parse(#"{"summary": "x"}"#, tasks: tasks) }
        #expect(throws: DayPlanError.noTasks) { try DayPlanService.parse(#"{"plan": [{"id": 1}]}"#, tasks: []) }
    }

    // MARK: - Генератор и согласие

    // Генератор: один запрос, ответ сопоставлен с переданными задачами; данные не меняются.
    @Test func генератор_планБезИзмененияДанных() async throws {
        let tasks = [task("А", deadline: date(21)), task("Б", deadline: date(20))]
        let selected = select(tasks)
        let provider = StubLLMProvider(.success(#"{"summary": "ok", "plan": [{"id": 2}, {"id": 1}]}"#))
        let plan = try await DayPlanGenerator(provider: provider).plan(for: selected, now: Self.now, calendar: Self.calendar)
        #expect(plan.items.map(\.title) == ["А", "Б"])
        #expect(provider.requests.count == 1)
        #expect(tasks.map(\.deadline) == [date(21), date(20)])
        #expect(tasks.allSatisfy { !$0.isCompleted })
    }

    // Согласие на отправку названий: по умолчанию нет, даётся и отзывается.
    @Test func согласие_поУмолчаниюНетДаётсяИОтзывается() {
        let name = "DayPlanServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(DayPlanService.hasConsent(defaults: defaults) == false)
        DayPlanService.giveConsent(defaults: defaults)
        #expect(DayPlanService.hasConsent(defaults: defaults))
        DayPlanService.revokeConsent(defaults: defaults)
        #expect(DayPlanService.hasConsent(defaults: defaults) == false)
    }

    // MARK: - Занятое время (D-44)

    private func meeting(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarMeeting {
        CalendarMeeting(id: title, title: title, start: start, end: end, isAllDay: allDay, calendarTitle: "Секретный календарь")
    }

    private func busySlots(_ events: [CalendarMeeting]) -> [String] {
        let meetings = CalendarMeetingRules.meetings(on: Self.now, from: events, calendar: Self.calendar)
        return DayPlanService.busySlots(from: meetings, now: Self.now, calendar: Self.calendar)
    }

    // «Весь день» первым; прошедшие отброшены; пересекающиеся и смежные склеены; уходящая за полночь — до 24:00.
    @Test func занятоеВремя_склейкаИПрошедшие() {
        let slots = busySlots([
            meeting("Отпуск", date(21), date(22), allDay: true),
            meeting("Утро", date(21, 9), date(21, 10)),
            meeting("Ночной перелёт", date(20, 22), date(21, 1)),
            meeting("Идёт сейчас", date(21, 11, 30), date(21, 12, 30)),
            meeting("Пересекается", date(21, 12, 15), date(21, 13)),
            meeting("Встык", date(21, 13), date(21, 13, 30)),
            meeting("После обеда", date(21, 15), date(21, 16)),
            meeting("Поздно", date(21, 23), date(22, 1)),
        ])

        #expect(slots == ["весь день", "11:30–13:30", "15:00–16:00", "23:00–24:00"])
    }

    // Промежутков не больше 20.
    @Test func занятоеВремя_неБольше20() {
        let events = (0..<25).map { index in
            let start = date(21, 12, 30).addingTimeInterval(Double(index) * 20 * 60)
            return meeting("Встреча \(index)", start, start.addingTimeInterval(10 * 60))
        }

        #expect(busySlots(events).count == DayPlanService.maxBusySlots)
    }

    // В запрос уходят только промежутки — без названий встреч и календарей; без встреч блока нет.
    @Test func запрос_занятоеВремяБезДанныхВстреч() throws {
        let items = DayPlanService.inputItems(
            for: select([task("Отчёт", deadline: date(21))]), now: Self.now, calendar: Self.calendar
        )
        let slots = busySlots([meeting("Тайное совещание", date(21, 15), date(21, 16))])

        let request = try DayPlanService.makeRequest(items: items, busySlots: slots, now: Self.now, calendar: Self.calendar)
        let everything = request.messages.map(\.content).joined(separator: "\n")
        #expect(request.messages[1].content == "1. Отчёт; приоритет: средний\n\nЗанятое время сегодня (встречи):\n15:00–16:00")
        #expect(!everything.contains("Тайное совещание"))
        #expect(!everything.contains("Секретный календарь"))

        let withoutMeetings = try DayPlanService.makeRequest(items: items, now: Self.now, calendar: Self.calendar)
        #expect(!withoutMeetings.messages[1].content.contains("Занятое время"))
    }

    // Согласие по старому составу данных (без занятого времени) не действует; отзыв убирает оба ключа.
    @Test func согласие_старогоНедостаточно() {
        let name = "DayPlanServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: DayPlanService.legacyConsentKey)

        #expect(DayPlanService.hasConsent(defaults: defaults) == false)
        DayPlanService.giveConsent(defaults: defaults)
        #expect(DayPlanService.hasConsent(defaults: defaults))
        #expect(defaults.object(forKey: DayPlanService.legacyConsentKey) == nil)

        defaults.set(true, forKey: DayPlanService.legacyConsentKey)
        DayPlanService.revokeConsent(defaults: defaults)
        #expect(defaults.object(forKey: DayPlanService.consentKey) == nil)
        #expect(defaults.object(forKey: DayPlanService.legacyConsentKey) == nil)
    }
}
