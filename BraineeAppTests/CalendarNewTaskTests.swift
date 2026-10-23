//
//  CalendarNewTaskTests.swift
//  BraineeAppTests
//
//  «+» во вкладке «Календарь» (п. 40): форма новой задачи со сроком выбранного дня без времени;
//  задача сохраняется во «Входящие»; на прошедший день — создаётся и считается просроченной.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct CalendarNewTaskTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = LLMTestSupport.calendar
    /// Среда, 21 октября 2026, 12:00 по Москве.
    private let now = LLMTestSupport.now

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private var service: TaskService {
        TaskService(context: context, onChange: { _ in }, log: SessionLog())
    }

    /// То, что отдаст форма, если ввести только название.
    private func formData(for snapshot: TaskFormSnapshot, deadline: Date) -> TaskFormData {
        TaskFormData(
            title: "Купить подарок",
            deadline: snapshot.hasDeadline ? deadline : nil,
            hasDeadlineTime: snapshot.hasDeadlineTime,
            reminderOffsets: snapshot.reminderOffsets,
            priority: snapshot.priority,
            status: snapshot.status,
            taskDetails: snapshot.taskDetails,
            selectedTags: []
        )
    }

    // Заготовка формы: срок включён, без времени, дата — начало выбранного дня; остальное — как у новой задачи.
    @Test func заготовка_срокВыбранногоДняБезВремени() {
        let day = LLMTestSupport.date(2026, 10, 23, 18, 45)
        let snapshot = TaskFormSnapshot.newTask(on: day, calendar: calendar)
        let startOfDay = calendar.startOfDay(for: day)

        #expect(snapshot.hasDeadline)
        #expect(!snapshot.hasDeadlineTime)
        #expect(snapshot.deadlineMinute == TaskFormSnapshot.minuteStamp(startOfDay))
        #expect(snapshot.title.isEmpty)
        #expect(snapshot.status == .new)
        #expect(snapshot.priority == TaskFormSnapshot().priority)
        #expect(snapshot.reminderOffsets.isEmpty)
    }

    // Сохранённая задача — во «Входящих», со сроком выбранного дня без времени, не просрочена.
    @Test func будущийДень_задачаВоВходящихБезПросрочки() {
        let day = LLMTestSupport.date(2026, 10, 23)
        let snapshot = TaskFormSnapshot.newTask(on: day, calendar: calendar)
        let task = service.create(from: formData(for: snapshot, deadline: calendar.startOfDay(for: day)))

        #expect(task.group == nil)
        #expect(task.deadline == calendar.startOfDay(for: day))
        #expect(!task.hasDeadlineTime)
        #expect(!task.isOverdue(at: now, calendar: calendar))
    }

    // Прошедший день не запрещён: задача создаётся и по обычным правилам просрочена.
    @Test func прошедшийДень_задачаСоздаётсяИПросрочена() {
        let day = LLMTestSupport.date(2026, 10, 19)
        let snapshot = TaskFormSnapshot.newTask(on: day, calendar: calendar)
        let task = service.create(from: formData(for: snapshot, deadline: calendar.startOfDay(for: day)))

        #expect(task.group == nil)
        #expect(task.isOverdue(at: now, calendar: calendar))
    }
}
