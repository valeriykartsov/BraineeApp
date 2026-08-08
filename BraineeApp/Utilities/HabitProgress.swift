//
//  HabitProgress.swift
//  BraineeApp
//
//  Процент выполнения привычек за день и сетка дат для contribution-календаря.

import Foundation
import CoreGraphics

enum HabitProgress {
    /// Доля выполненных привычек в день (0…1). Без привычек — 0.
    static func completionRatio(
        for day: Date,
        habits: [Habit],
        calendar: Calendar = .current
    ) -> Double {
        guard !habits.isEmpty else { return 0 }
        let completed = habits.filter { $0.isCompleted(on: day, calendar: calendar) }.count
        return Double(completed) / Double(habits.count)
    }

    /// Недели: `weeksBefore` слева + текущая; `weeksAfter` справа (у GitHub обычно 0).
    static func contributionDays(
        weeksBefore: Int,
        weeksAfter: Int,
        centeredOn center: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: center)
        let weekday = calendar.component(.weekday, from: today)
        let firstWeekday = calendar.firstWeekday
        let daysFromWeekStart = (weekday - firstWeekday + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromWeekStart, to: today),
              let gridStart = calendar.date(byAdding: .day, value: -weeksBefore * 7, to: weekStart) else {
            return []
        }
        let totalDays = (weeksBefore + 1 + weeksAfter) * 7
        return (0..<totalDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    /// Сколько недель помещается в ширину; текущая неделя справа.
    /// Учитывает реальные отступы между месяцами, чтобы сетка не вылезала за край.
    static func weekSpan(
        forAvailableWidth width: CGFloat,
        labelColumnWidth: CGFloat = 22,
        gap: CGFloat = 3,
        monthGap: CGFloat = 8,
        minCell: CGFloat = 10,
        centeredOn: Date = .now,
        calendar: Calendar = .current
    ) -> (weeksBefore: Int, weeksAfter: Int, cellSize: CGFloat) {
        let gridWidth = max(width - labelColumnWidth - gap, minCell)
        var weekCount = max(7, Int((gridWidth + gap) / (minCell + gap)))

        while weekCount >= 7 {
            let weeksBefore = weekCount - 1
            let days = contributionDays(
                weeksBefore: weeksBefore,
                weeksAfter: 0,
                centeredOn: centeredOn,
                calendar: calendar
            )
            let columns = columns(from: days)
            let boundaries = monthBoundaryIndices(after: columns, calendar: calendar)
            let gapsWidth = gapWidth(
                weekCount: weekCount,
                boundaryCount: boundaries.count,
                gap: gap,
                monthGap: monthGap
            )
            let cellSize = (gridWidth - gapsWidth) / CGFloat(weekCount)
            if cellSize >= minCell {
                // Чуть уменьшаем, чтобы float-округление не выталкивало последний столбец.
                return (weeksBefore, 0, floor(cellSize * 10) / 10)
            }
            weekCount -= 1
        }

        return (6, 0, minCell)
    }

    static func columns(from days: [Date]) -> [[Date]] {
        stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }

    static func gapWidth(
        weekCount: Int,
        boundaryCount: Int,
        gap: CGFloat,
        monthGap: CGFloat
    ) -> CGFloat {
        let regular = max(weekCount - 1 - boundaryCount, 0)
        return CGFloat(regular) * gap + CGFloat(boundaryCount) * monthGap
    }

    /// Индексы колонок, после которых нужен дополнительный отступ (смена месяца).
    static func monthBoundaryIndices(
        after columns: [[Date]],
        calendar: Calendar = .current
    ) -> Set<Int> {
        var result = Set<Int>()
        for index in 0..<(columns.count - 1) {
            guard let current = columns[index].first,
                  let next = columns[index + 1].first else { continue }
            if !calendar.isDate(current, equalTo: next, toGranularity: .month) {
                result.insert(index)
            }
        }
        return result
    }
}
