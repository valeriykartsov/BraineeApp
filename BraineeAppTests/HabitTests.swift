//
//  HabitTests.swift
//  BraineeAppTests
//
//  Привычки: отметки по дням, лимит 7, процент за день, миграция JSON.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct HabitTests {

    @Test func переключениеОтметки_добавляетИСнимаетДень() {
        // Чекбокс как у задач: повторный тап снимает отметку за сегодня.
        let habit = Habit(title: "Вода")
        let day = Date()
        #expect(habit.isCompleted(on: day) == false)
        habit.toggleCompletion(on: day)
        #expect(habit.isCompleted(on: day) == true)
        habit.toggleCompletion(on: day)
        #expect(habit.isCompleted(on: day) == false)
    }

    @Test func процентДня_считаетДолюВыполненных() throws {
        let container = try TestHelpers.makeContainer()
        let a = Habit(title: "A")
        let b = Habit(title: "B")
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        a.toggleCompletion(on: .now)

        let ratio = HabitProgress.completionRatio(for: .now, habits: [a, b])
        #expect(ratio == 0.5)
        #expect(HabitProgress.completionRatio(for: .now, habits: []) == 0)
    }

    @Test func normalize_обрезаетБольшеСемиПривычек() {
        // В JSON не больше 7 привычек — защита лимита.
        var habits: [HabitRecord] = (0..<10).map { index in
            HabitRecord(
                id: UUID(),
                title: "H\(index)",
                sortOrder: index,
                createdAt: .now
            )
        }
        var document = MyTasksDocument(
            version: 3,
            lastSavedAt: nil,
            tags: [],
            groups: [],
            tasks: [],
            habits: habits
        )
        document.normalizeRecords()
        #expect(document.habits.count == Habit.maxCount)
        #expect(document.version == MyTasksDocument.currentVersion)
    }

    @Test func сеткаContribution_текущаяНеделяСправаКакGitHub() {
        // Как у GitHub: текущая неделя — крайний правый столбец, слева только прошлое.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let width: CGFloat = 320
        let span = HabitProgress.weekSpan(forAvailableWidth: width)
        #expect(span.weeksAfter == 0)
        #expect(span.weeksBefore >= 6)

        let days = HabitProgress.contributionDays(
            weeksBefore: span.weeksBefore,
            weeksAfter: span.weeksAfter
        )
        #expect(days.count == (span.weeksBefore + 1) * 7)
        #expect(days.contains(where: { calendar.isDate($0, inSameDayAs: today) }))
        // Сегодня не левее последней недели: правый край сетки — текущая неделя.
        let lastSeven = Array(days.suffix(7))
        #expect(lastSeven.contains(where: { calendar.isDate($0, inSameDayAs: today) }))

        // Сетка с учётом month-gap не шире доступной области.
        let columns = HabitProgress.columns(from: days)
        let boundaries = HabitProgress.monthBoundaryIndices(after: columns)
        let weekCount = span.weeksBefore + 1
        let gaps = HabitProgress.gapWidth(
            weekCount: weekCount,
            boundaryCount: boundaries.count,
            gap: 3,
            monthGap: 8
        )
        let gridWidth = CGFloat(weekCount) * span.cellSize + gaps
        let available = width - 22 - 3
        #expect(gridWidth <= available + 0.5)
    }

    @Test func отступМеждуМесяцами_наГраницеМесяцев() {
        // Между колонками разных месяцев помечаем границу для визуального gap.
        let calendar = Calendar.current
        let jan = calendar.date(from: DateComponents(year: 2026, month: 1, day: 26))!
        let feb = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let columns: [[Date]] = [
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: jan) },
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: feb) }
        ]
        let boundaries = HabitProgress.monthBoundaryIndices(after: columns)
        #expect(boundaries.contains(0))
    }

    @Test func перестановкаСортировки_обновляетПорядок() throws {
        // Drag-and-drop меняет sortOrder: A,B,C → B,A,C.
        let container = try TestHelpers.makeContainer()
        let a = Habit(title: "A", sortOrder: 0)
        let b = Habit(title: "B", sortOrder: 1)
        let c = Habit(title: "C", sortOrder: 2)
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(c)

        var ordered = [a, b, c]
        ordered.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        for (index, habit) in ordered.enumerated() {
            habit.sortOrder = index
        }

        #expect(ordered.map(\.title) == ["B", "A", "C"])
        #expect(a.sortOrder == 1)
        #expect(b.sortOrder == 0)
        #expect(c.sortOrder == 2)
    }
}
