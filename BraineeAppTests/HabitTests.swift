//
//  HabitTests.swift
//  BraineeAppTests
//
//  Привычки: отметки по дням, лимит 7, прогресс за день, миграция JSON.

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

    @Test func окноТрёхМесяцев_полныйТекущийИДваПредыдущих() {
        // Справа — полный текущий месяц (включая будущие дни), слева — 2 предыдущих.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // понедельник
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!

        let days = HabitProgress.threeMonthContributionDays(
            previousMonths: 2,
            centeredOn: today,
            calendar: calendar
        )
        #expect(!days.isEmpty)

        let june1 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let aug31 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        #expect(days.contains(where: { calendar.isDate($0, inSameDayAs: june1) }))
        #expect(days.contains(where: { calendar.isDate($0, inSameDayAs: aug31) }))
        #expect(days.contains(where: { calendar.isDate($0, inSameDayAs: today) }))

        let columns = HabitProgress.columns(from: days)
        let bands = HabitProgress.monthBands(
            for: columns,
            centeredOn: today,
            previousMonths: 2,
            calendar: calendar
        )
        #expect(bands.count == 3)
        #expect(bands.map(\.month) == [6, 7, 8])
        // Текущий месяц — последняя полоса и занимает несколько колонок (полный месяц).
        #expect(bands.last?.month == 8)
        #expect((bands.last?.columnEndExclusive ?? 0) - (bands.last?.columnStart ?? 0) >= 4)
        // Хвост недели после 31 августа может заходить в сентябрь, но отдельной полосы «сент» нет.
        #expect(bands.last?.columnEndExclusive == columns.count)
    }

    @Test func подписиМесяцев_триПолосыСЦентрами() {
        // Три полосы месяцев — для выравнивания подписи по центру блока.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
        let days = HabitProgress.threeMonthContributionDays(centeredOn: today, calendar: calendar)
        let columns = HabitProgress.columns(from: days)
        let ranges = HabitProgress.monthColumnRanges(
            for: columns,
            centeredOn: today,
            calendar: calendar
        )
        #expect(ranges.count == 3)
        #expect(ranges[0].start == 0)
        #expect(ranges[2].endExclusive == columns.count)
    }

    @Test func размерЯчеекТрёхМесяцев_помещаетсяВШирину() {
        // Сетка трёх месяцев не шире доступной области.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
        let width: CGFloat = 320
        let layout = HabitProgress.cellSizeForThreeMonthWindow(
            availableWidth: width,
            labelColumnWidth: 22,
            gap: 3,
            monthGap: 8,
            minCell: 8,
            centeredOn: today,
            calendar: calendar
        )
        let available = width - 22 - 3
        #expect(layout.gridWidth <= available + 0.5)
        #expect(layout.bands.count == 3)
        #expect(layout.cellSize >= 4)
    }

    @Test func отступМеждуМесяцами_наГраницеМесяцев() {
        // Между колонками разных месяцев помечаем границу для визуального gap.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
        let days = HabitProgress.threeMonthContributionDays(centeredOn: today, calendar: calendar)
        let columns = HabitProgress.columns(from: days)
        let boundaries = HabitProgress.monthBoundaryIndices(
            after: columns,
            centeredOn: today,
            calendar: calendar
        )
        #expect(boundaries.count == 2)
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
