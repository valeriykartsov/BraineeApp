//
//  TaskReminderOffsetTests.swift
//  BraineeAppTests
//
//  Пресеты напоминаний как в Calendar: список, миграция, fireDate.

import Foundation
import Testing
@testable import BraineeApp

struct TaskReminderOffsetTests {

    @Test func titles_какВКалендаре() {
        // Подписи совпадают с нативным меню «Уведомление».
        #expect(TaskReminderOffset.atEvent.title == "В момент события")
        #expect(TaskReminderOffset.minutes5.title == "За 5 минут")
        #expect(TaskReminderOffset.hours2.title == "За 2 часа")
        #expect(TaskReminderOffset.week1.title == "За неделю")
    }

    @Test func normalizedList_безДублейИНеБольшеТрёх() {
        // До 3 уникальных пресетов.
        let raw = [
            TaskReminderOffset.hours1.rawValue,
            TaskReminderOffset.hours1.rawValue,
            TaskReminderOffset.minutes5.rawValue,
            "unknown",
            TaskReminderOffset.days1.rawValue,
            TaskReminderOffset.week1.rawValue
        ]
        let list = TaskReminderOffset.normalizedList(raw)
        #expect(list.count == 3)
        #expect(list == [.hours1, .minutes5, .days1])
    }

    @Test func migrated_изСтарогоФормата() {
        // v7 value+unit → ближайший пресет.
        #expect(TaskReminderOffset.migrated(fromValue: 15, unitRaw: "minutes") == .minutes15)
        #expect(TaskReminderOffset.migrated(fromValue: 1, unitRaw: "hours") == .hours1)
        #expect(TaskReminderOffset.migrated(fromValue: 7, unitRaw: "days") == .week1)
    }

    @Test func fireDate_заДваЧасаДоДедлайнаСВременем() {
        let calendar = Calendar(identifier: .gregorian)
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 15, minute: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10, minute: 0))!
        let fire = TaskReminderOffset.hours2.fireDate(
            deadline: deadline,
            hasDeadlineTime: true,
            now: now,
            calendar: calendar
        )
        let expected = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 13, minute: 0))!
        #expect(fire == expected)
    }

    @Test func fireDate_вМоментСобытия() {
        let calendar = Calendar(identifier: .gregorian)
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 15, minute: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10, minute: 0))!
        let fire = TaskReminderOffset.atEvent.fireDate(
            deadline: deadline,
            hasDeadlineTime: true,
            now: now,
            calendar: calendar
        )
        #expect(fire == deadline)
    }

    @Test func fireDate_вПрошлом_nil() {
        let calendar = Calendar(identifier: .gregorian)
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 12, minute: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 13, minute: 0))!
        let fire = TaskReminderOffset.hours1.fireDate(
            deadline: deadline,
            hasDeadlineTime: true,
            now: now,
            calendar: calendar
        )
        #expect(fire == nil)
    }

    @Test func legacyJSON_мигрируетВOffsets() throws {
        // Старый JSON с hasReminder/value/unit читается как один пресет.
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Старое",
          "deadline": "2026-08-10T12:00:00Z",
          "hasReminder": true,
          "reminderValue": 2,
          "reminderUnitRaw": "hours",
          "priorityRaw": 1,
          "categoryRaw": "tasks",
          "createdAt": "2026-08-01T12:00:00Z",
          "taskDetails": "",
          "sortOrder": 0,
          "tagIDs": []
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(TaskRecord.self, from: json)
        #expect(record.reminderOffsetsRaw == [TaskReminderOffset.hours2.rawValue])
    }
}
