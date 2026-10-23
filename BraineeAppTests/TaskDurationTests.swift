//
//  TaskDurationTests.swift
//  BraineeAppTests
//
//  Длительность задачи (D-40): список и подписи, правило «только у задачи со временем»,
//  сохранение через TaskService, снимок формы, событие Календаря, журнал сессии.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskDurationTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let start = PersistenceFixtures.date(86_400)

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private var service: TaskService {
        TaskService(context: context, onChange: { _ in }, log: SessionLog())
    }

    private func form(deadline: Date?, hasTime: Bool, duration: Int?) -> TaskFormData {
        TaskFormData(
            title: "Созвон",
            deadline: deadline,
            hasDeadlineTime: hasTime,
            reminderOffsets: [],
            priority: .medium,
            status: .new,
            taskDetails: "",
            selectedTags: [],
            durationMinutes: duration
        )
    }

    // Список в форме — 30 мин…3 ч с шагом полчаса; подписи по-русски, «1,5 ч» с запятой.
    @Test func списокИПодписи_какВРешении() {
        #expect(TaskDuration.options == [30, 60, 90, 120, 150, 180])
        #expect(TaskDuration.options.map(TaskDuration.title) == ["30 мин", "1 ч", "1,5 ч", "2 ч", "2,5 ч", "3 ч"])
        #expect(TaskDuration.title(75) == "1 ч 15 мин")
    }

    // В данных хранится только выбранное отличие от 30 мин и только у задачи со временем.
    @Test func хранимоеЗначение_толькоУЗадачиСоВременем() {
        #expect(TaskDuration.stored(90, hasDeadlineTime: true) == 90)
        #expect(TaskDuration.stored(30, hasDeadlineTime: true) == nil)
        #expect(TaskDuration.stored(90, hasDeadlineTime: false) == nil)
        #expect(TaskDuration.stored(0, hasDeadlineTime: true) == nil)
        #expect(TaskDuration.effective(nil) == 30)
        #expect(TaskDuration.effective(120) == 120)
    }

    // Создание и изменение через сервис: длительность сохраняется; убрали время — сброс.
    @Test func сервис_сохраняетИСбрасываетДлительность() {
        let task = service.create(from: form(deadline: start, hasTime: true, duration: 90))
        #expect(task.durationMinutes == 90)
        #expect(task.effectiveDurationMinutes == 90)

        service.update(task, from: form(deadline: start, hasTime: false, duration: 90))
        #expect(task.durationMinutes == nil)

        service.update(task, from: form(deadline: start, hasTime: true, duration: 150))
        #expect(task.durationMinutes == 150)
        service.update(task, from: form(deadline: nil, hasTime: true, duration: 150))
        #expect(task.durationMinutes == nil)
        #expect(!task.hasDeadlineTime)
    }

    // Выбор «30 мин» у старой задачи без длительности не считается изменением формы.
    @Test func снимокФормы_30минутИПустоОдинаковы() {
        let empty = TaskFormSnapshot(hasDeadline: true, hasDeadlineTime: true, deadline: start)
        let thirty = TaskFormSnapshot(hasDeadline: true, hasDeadlineTime: true, deadline: start, durationMinutes: 30)
        let hour = TaskFormSnapshot(hasDeadline: true, hasDeadlineTime: true, deadline: start, durationMinutes: 60)
        #expect(empty == thirty)
        #expect(empty != hour)
    }

    // Событие Календаря длится столько же, сколько задача; без выбора — 30 минут (D-40).
    @Test func событиеКалендаря_длитсяСтолькоЖеСколькоЗадача() throws {
        let task = service.create(from: form(deadline: start, hasTime: true, duration: 120))
        let event = try #require(CalendarEventRules.draft(for: task))
        #expect(event.start == start)
        #expect(event.end == start.addingTimeInterval(2 * 3600))

        let plain = service.create(from: form(deadline: start, hasTime: true, duration: nil))
        let plainEvent = try #require(CalendarEventRules.draft(for: plain))
        #expect(plainEvent.end == start.addingTimeInterval(30 * 60))
        // Смена длительности — событие нужно переписать.
        #expect(CalendarEventRules.needsUpdate(plainEvent, to: event.with(url: plainEvent.url, title: plainEvent.title)))
    }

    // Журнал: смена длительности — строка «было → стало»; появление времени — только «Срок».
    @Test func журнал_строкаДлительности() {
        let log = SessionLog()
        let service = TaskService(context: context, onChange: { _ in }, log: log)
        let task = service.create(from: form(deadline: start, hasTime: true, duration: nil))

        let before = TaskLogFields(task)
        service.update(task, from: form(deadline: start, hasTime: true, duration: 90))
        #expect(TaskLogFields.changes(from: before, to: TaskLogFields(task)) == ["Длительность: 30 мин → 1,5 ч"])

        let untimed = service.create(from: form(deadline: start, hasTime: false, duration: nil))
        let beforeTime = TaskLogFields(untimed)
        service.update(untimed, from: form(deadline: start, hasTime: true, duration: 60))
        let changes = TaskLogFields.changes(from: beforeTime, to: TaskLogFields(untimed))
        #expect(changes.count == 1)
        #expect(changes.first?.hasPrefix("Срок:") == true)
    }
}

private extension CalendarEventDraft {
    func with(url: URL?, title: String) -> CalendarEventDraft {
        var copy = self
        copy.url = url
        copy.title = title
        return copy
    }
}
