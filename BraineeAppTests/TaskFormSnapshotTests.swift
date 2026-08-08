//
//  TaskFormSnapshotTests.swift
//  BraineeAppTests
//
//  Снимок формы: dirty-флаг и сравнение полей.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskFormSnapshotTests {

    @Test func одинаковыеСнимки_равны() {
        // Без изменений форма не должна считаться «грязной».
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = TaskFormSnapshot(
            title: "A",
            taskDetails: "d",
            status: .new,
            priority: .medium,
            hasDeadline: true,
            hasDeadlineTime: true,
            deadline: date,
            reminderOffsets: [.hours2, .minutes5],
            selectedTagUUIDs: []
        )
        let b = TaskFormSnapshot(
            title: "A",
            taskDetails: "d",
            status: .new,
            priority: .medium,
            hasDeadline: true,
            hasDeadlineTime: true,
            deadline: date.addingTimeInterval(15),
            reminderOffsets: [.hours2, .minutes5],
            selectedTagUUIDs: []
        )
        #expect(a == b)
    }

    @Test func изменениеНазвания_снимкиНеРавны() {
        let base = TaskFormSnapshot(title: "Старое")
        let edited = TaskFormSnapshot(title: "Новое")
        #expect(base != edited)
    }

    @Test func снимокИзЗадачи_копируетНапоминания() throws {
        let container = try TestHelpers.makeContainer()
        let deadline = Date(timeIntervalSince1970: 1_700_000_400)
        let task = TaskItem(
            title: "T",
            deadline: deadline,
            hasDeadlineTime: true,
            reminderOffsets: [.minutes15, .days1],
            priority: .high,
            status: .inProgress,
            taskDetails: "описание"
        )
        container.mainContext.insert(task)

        let snap = TaskFormSnapshot(task: task)
        #expect(snap.title == "T")
        #expect(snap.reminderOffsets == [.minutes15, .days1])
        #expect(snap.hasDeadlineTime == true)
    }
}
