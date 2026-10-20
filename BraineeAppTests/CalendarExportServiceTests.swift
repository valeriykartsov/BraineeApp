//
//  CalendarExportServiceTests.swift
//  BraineeAppTests
//
//  Сверка задач с календарём «BraineeApp» (roadmap CAL-2, D-05, D-22) на подставном хранилище
//  событий — настоящий Календарь и файл связей не трогаются.

import Foundation
import Testing
@testable import BraineeApp

/// Календарь в памяти: считает сохранения и удаления, как EventKit отдаёт события только своего календаря.
@MainActor
private final class FakeCalendarStore: CalendarEventStore {
    var access: CalendarAccess = .fullAccess
    var calendars: [String: String] = [:]  // id → название
    var events: [String: (calendarID: String, draft: CalendarEventDraft)] = [:]
    var saves = 0
    var removals = 0
    var calendarsCreated = 0
    var canCreateCalendar = true
    private var nextID = 0

    func requestAccess() async -> Bool { access == .fullAccess }

    func calendarSummary(id: String) -> String? {
        calendars[id].map { "\($0) · iCloud" }
    }

    func writableCalendarIDs(titled title: String) -> [String] {
        calendars.filter { $0.value == title }.map(\.key).sorted()
    }

    func createCalendar(title: String) throws -> String {
        guard canCreateCalendar else { throw CalendarExportError.noCalendarSource }
        calendarsCreated += 1
        let id = makeID("cal")
        calendars[id] = title
        return id
    }

    func event(id: String, calendarID: String) -> CalendarEventRecord? {
        guard let stored = events[id], stored.calendarID == calendarID else { return nil }
        return CalendarEventRecord(id: id, draft: stored.draft)
    }

    func events(calendarID: String, from: Date, to: Date) -> [CalendarEventRecord] {
        events.filter { $0.value.calendarID == calendarID && $0.value.draft.start >= from && $0.value.draft.start < to }
            .map { CalendarEventRecord(id: $0.key, draft: $0.value.draft) }
    }

    func save(_ draft: CalendarEventDraft, eventID: String?, calendarID: String) throws -> String {
        saves += 1
        let id = eventID ?? makeID("ev")
        events[id] = (calendarID, draft)
        return id
    }

    func removeEvent(id: String) throws {
        if events.removeValue(forKey: id) != nil { removals += 1 }
    }

    /// Пользователь удалил календарь в приложении Календарь — события пропадают вместе с ним.
    func deleteCalendar(_ id: String) {
        calendars[id] = nil
        events = events.filter { $0.value.calendarID != id }
    }

    func eventDrafts(in calendarID: String) -> [CalendarEventDraft] {
        events.values.filter { $0.calendarID == calendarID }.map(\.draft)
    }

    private func makeID(_ prefix: String) -> String {
        nextID += 1
        return "\(prefix)-\(nextID)"
    }
}

@MainActor
private final class MemoryLinks: CalendarLinksStoring {
    var links = CalendarLinks()
    func load() -> CalendarLinks { links }
    func save(_ links: CalendarLinks) throws { self.links = links }
}

@MainActor
struct CalendarExportServiceTests {
    private let store = FakeCalendarStore()
    private let links = MemoryLinks()
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    private var service: CalendarExportService {
        CalendarExportService(store: store, links: links, now: { [now] in now })
    }

    private func draft(_ title: String, hoursFromNow: Double = 2, allDay: Bool = false) -> CalendarEventDraft {
        CalendarEventRules.draft(
            title: title,
            deadline: now.addingTimeInterval(hoursFromNow * 3600),
            hasDeadlineTime: !allDay,
            isDone: false,
            isSoftDeleted: false,
            details: "",
            uuid: UUID()
        )!
    }

    private func key(_ draft: CalendarEventDraft) -> String {
        CalendarEventRules.taskUUID(from: draft.url)!.uuidString
    }

    // Первое включение: создаётся один календарь «BraineeApp» и по событию на задачу.
    @Test func первыйЭкспорт_создаётКалендарьИСобытия() throws {
        let a = draft("A"), b = draft("B", allDay: true)
        let summary = try service.sync(drafts: [key(a): a, key(b): b])

        #expect(summary == .init(created: 2, updated: 0, removed: 0, calendarCreated: true))
        #expect(store.calendars.values.sorted() == ["BraineeApp"])
        #expect(links.links.events.count == 2)
        #expect(store.events.count == 2)
    }

    // Повторная сверка без изменений ничего не переписывает и не создаёт дублей.
    @Test func повторнаяСверка_безИзменений_ничегоНеПишет() throws {
        let a = draft("A")
        try service.sync(drafts: [key(a): a])
        let savesAfterFirst = store.saves

        for _ in 0..<5 {
            let summary = try service.sync(drafts: [key(a): a])
            #expect(summary == .init())
        }
        #expect(store.saves == savesAfterFirst)
        #expect(store.events.count == 1)
        #expect(store.calendarsCreated == 1)
    }

    // Изменение задачи обновляет то же событие (тот же id), без дублей после нескольких правок.
    @Test func изменениеЗадачи_обновляетТоЖеСобытие() throws {
        var a = draft("A")
        try service.sync(drafts: [key(a): a])
        let eventID = try #require(links.links.events[key(a)])

        for index in 1...5 {
            a.title = "A\(index)"
            a.start = a.start.addingTimeInterval(900)
            a.end = a.end.addingTimeInterval(900)
            let summary = try service.sync(drafts: [key(a): a])
            #expect(summary.updated == 1)
            #expect(summary.created == 0)
        }
        #expect(store.events.count == 1)
        #expect(links.links.events[key(a)] == eventID)
        #expect(store.events[eventID]?.draft.title == "A5")
    }

    // Задача пропала из списка (выполнена, удалена, без даты) — её событие удаляется, другие остаются.
    @Test func задачаБольшеНеЭкспортируется_событиеУдаляется() throws {
        let a = draft("A"), b = draft("B")
        try service.sync(drafts: [key(a): a, key(b): b])

        let summary = try service.sync(drafts: [key(b): b])

        #expect(summary.removed == 1)
        #expect(store.eventDrafts(in: links.links.calendarID!).map(\.title) == ["B"])
        #expect(links.links.events.keys.sorted() == [key(b)])
    }

    // Возврат задачи (снята отметка, восстановлена из корзины) — событие создаётся снова.
    @Test func возвратЗадачи_событиеСоздаётсяСнова() throws {
        let a = draft("A")
        try service.sync(drafts: [key(a): a])
        try service.sync(drafts: [:])
        #expect(store.events.isEmpty)

        let summary = try service.sync(drafts: [key(a): a])
        #expect(summary.created == 1)
        #expect(store.events.count == 1)
    }

    // Календарь удалён в приложении Календарь — создаётся новый и в него заново пишутся события (D-05).
    @Test func удалённыйКалендарь_создаётсяЗаново() throws {
        let a = draft("A")
        try service.sync(drafts: [key(a): a])
        let oldCalendar = try #require(links.links.calendarID)
        store.deleteCalendar(oldCalendar)

        let summary = try service.sync(drafts: [key(a): a])

        #expect(summary.calendarCreated)
        #expect(summary.created == 1)
        #expect(links.links.calendarID != oldCalendar)
        #expect(store.calendars.count == 1)
        #expect(store.events.count == 1)
    }

    // Связи потеряны (переустановка, битый файл): существующий календарь и события находятся
    // по названию и меткам — без второго календаря и без дублей событий.
    @Test func потеряныСвязи_событияНаходятсяПоМеткам() throws {
        let a = draft("A"), b = draft("B")
        try service.sync(drafts: [key(a): a, key(b): b])
        let eventIDs = Set(store.events.keys)
        links.links = CalendarLinks()

        let summary = try service.sync(drafts: [key(a): a, key(b): b])

        #expect(summary == .init())
        #expect(store.calendarsCreated == 1)
        #expect(Set(store.events.keys) == eventIDs)
        #expect(Set(links.links.events.values) == eventIDs)
    }

    // Связь указывает на пропавшее событие (удалено в Календаре) — создаётся новое.
    @Test func событиеУдаленоВКалендаре_создаётсяНовое() throws {
        let a = draft("A")
        try service.sync(drafts: [key(a): a])
        store.events.removeAll()

        let summary = try service.sync(drafts: [key(a): a])

        #expect(summary.created == 1)
        #expect(store.events.count == 1)
    }

    // Дубли одной задачи в календаре (например, после потери связей) — остаётся одно событие;
    // события задач, которых нет в списке, убираются; чужие события календаря не трогаются.
    @Test func дублиИЛишниеСобытия_убираются_чужиеОстаются() throws {
        let a = draft("A"), gone = draft("Gone")
        try service.sync(drafts: [key(a): a])
        let calendarID = try #require(links.links.calendarID)
        _ = try store.save(a, eventID: nil, calendarID: calendarID)
        _ = try store.save(gone, eventID: nil, calendarID: calendarID)
        var foreign = draft("Чужое")
        foreign.url = nil
        _ = try store.save(foreign, eventID: nil, calendarID: calendarID)
        links.links.events = [:]

        let summary = try service.sync(drafts: [key(a): a])

        #expect(summary.removed == 2)
        #expect(store.eventDrafts(in: calendarID).map(\.title).sorted() == ["A", "Чужое"])
    }

    // Без полного доступа сверка не начинается и ничего не меняет.
    @Test func безДоступа_ошибкаИНичегоНеМеняется() throws {
        store.access = .writeOnly
        let a = draft("A")

        #expect(throws: CalendarExportError.noAccess) {
            try service.sync(drafts: [key(a): a])
        }
        #expect(store.calendars.isEmpty)
        #expect(links.links == CalendarLinks())
    }

    // Негде создать календарь (нет ни iCloud, ни локального источника) — понятная ошибка (D-05).
    @Test func нетИсточникаКалендарей_понятнаяОшибка() throws {
        store.canCreateCalendar = false
        let a = draft("A")

        #expect(throws: CalendarExportError.noCalendarSource) {
            try service.sync(drafts: [key(a): a])
        }
        #expect(store.events.isEmpty)
    }

    // Задачи из SwiftData: выполненная, удалённая и без даты не экспортируются.
    @Test func задачиИзХранилища_экспортируютсяТолькоАктивныеСДатой() throws {
        let tasks = [
            TaskItem(title: "С датой", deadline: now.addingTimeInterval(3600), hasDeadlineTime: true),
            TaskItem(title: "Без даты"),
            TaskItem(title: "Готово", deadline: now.addingTimeInterval(3600), status: .done),
            TaskItem(title: "В корзине", deadline: now.addingTimeInterval(3600), isSoftDeleted: true),
        ]

        let summary = try service.sync(tasks: tasks)

        #expect(summary.created == 1)
        #expect(store.events.values.map(\.draft.title) == ["С датой"])
    }
}
