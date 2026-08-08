//
//  HabitProgress.swift
//  BraineeApp
//
//  Процент выполнения привычек за день и сетка дат для contribution-календаря.

import Foundation
import CoreGraphics

/// Полоса одного месяца в contribution-сетке.
struct HabitCalendarMonthBand: Equatable {
    let year: Int
    let month: Int
    let label: String
    /// Индекс первой колонки (включительно).
    let columnStart: Int
    /// Индекс после последней колонки.
    let columnEndExclusive: Int
}

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

    /// Дни окна: `previousMonths` предыдущих + полный текущий месяц (до конца месяца).
    /// Сетка выровнена по неделям (как GitHub contribution).
    static func threeMonthContributionDays(
        previousMonths: Int = 2,
        centeredOn center: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: center)
        let monthComps = calendar.dateComponents([.year, .month], from: today)
        guard let currentMonthStart = calendar.date(from: monthComps),
              let windowStart = calendar.date(byAdding: .month, value: -previousMonths, to: currentMonthStart),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let windowEnd = calendar.date(byAdding: .day, value: -1, to: nextMonthStart) else {
            return []
        }

        let startWeekOffset = (calendar.component(.weekday, from: windowStart) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -startWeekOffset, to: windowStart) else {
            return []
        }

        let endWeekOffset = (calendar.component(.weekday, from: windowEnd) - calendar.firstWeekday + 7) % 7
        let daysToWeekEnd = 6 - endWeekOffset
        guard let gridEnd = calendar.date(byAdding: .day, value: daysToWeekEnd, to: windowEnd) else {
            return []
        }

        var days: [Date] = []
        var cursor = gridStart
        while cursor <= gridEnd {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Недели: `weeksBefore` слева + текущая; `weeksAfter` справа (legacy / тесты).
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
        centeredOn center: Date = .now,
        calendar: Calendar = .current
    ) -> Set<Int> {
        let bands = monthBands(for: columns, centeredOn: center, calendar: calendar)
        var result = Set<Int>()
        for band in bands.dropLast() {
            let lastColumn = band.columnEndExclusive - 1
            if lastColumn >= 0 {
                result.insert(lastColumn)
            }
        }
        return result
    }

    /// Диапазон колонок месяца: `[start, endExclusive)`.
    static func monthColumnRanges(
        for columns: [[Date]],
        centeredOn center: Date = .now,
        calendar: Calendar = .current
    ) -> [(start: Int, endExclusive: Int)] {
        monthBands(for: columns, centeredOn: center, calendar: calendar).map {
            (start: $0.columnStart, endExclusive: $0.columnEndExclusive)
        }
    }

    /// Полосы месяцев с подписями (для центрирования над блоками).
    static func monthBands(
        for columns: [[Date]],
        centeredOn center: Date = .now,
        previousMonths: Int = 2,
        calendar: Calendar = .current
    ) -> [HabitCalendarMonthBand] {
        guard !columns.isEmpty else { return [] }

        let today = calendar.startOfDay(for: center)
        let monthComps = calendar.dateComponents([.year, .month], from: today)
        guard let currentMonthStart = calendar.date(from: monthComps),
              let windowStart = calendar.date(byAdding: .month, value: -previousMonths, to: currentMonthStart),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let windowEnd = calendar.date(byAdding: .day, value: -1, to: nextMonthStart) else {
            return []
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLL"

        var bands: [HabitCalendarMonthBand] = []
        var index = 0
        while index < columns.count {
            let week = columns[index]
            guard let monthDate = monthAnchor(for: week, windowStart: windowStart, windowEnd: windowEnd, calendar: calendar) else {
                index += 1
                continue
            }
            let comps = calendar.dateComponents([.year, .month], from: monthDate)
            var end = index + 1
            while end < columns.count {
                guard let nextAnchor = monthAnchor(
                    for: columns[end],
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    calendar: calendar
                ) else { break }
                let nextComps = calendar.dateComponents([.year, .month], from: nextAnchor)
                if nextComps.year != comps.year || nextComps.month != comps.month { break }
                end += 1
            }
            let label = formatter.string(from: monthDate).replacingOccurrences(of: ".", with: "")
            bands.append(
                HabitCalendarMonthBand(
                    year: comps.year ?? 0,
                    month: comps.month ?? 0,
                    label: label,
                    columnStart: index,
                    columnEndExclusive: end
                )
            )
            index = end
        }
        return bands
    }

    /// Размер ячейки, чтобы все недели трёх месяцев поместились в ширину.
    static func cellSizeForThreeMonthWindow(
        availableWidth: CGFloat,
        labelColumnWidth: CGFloat = 22,
        gap: CGFloat = 3,
        monthGap: CGFloat = 8,
        minCell: CGFloat = 8,
        centeredOn: Date = .now,
        calendar: Calendar = .current
    ) -> (columns: [[Date]], bands: [HabitCalendarMonthBand], cellSize: CGFloat, gridWidth: CGFloat) {
        let days = threeMonthContributionDays(centeredOn: centeredOn, calendar: calendar)
        let columns = columns(from: days)
        let bands = monthBands(for: columns, centeredOn: centeredOn, calendar: calendar)
        let weekCount = max(columns.count, 1)
        let boundaryCount = max(bands.count - 1, 0)
        let gaps = gapWidth(
            weekCount: weekCount,
            boundaryCount: boundaryCount,
            gap: gap,
            monthGap: monthGap
        )
        let gridAvailable = max(availableWidth - labelColumnWidth - gap, minCell)
        let raw = max(0, (gridAvailable - gaps) / CGFloat(weekCount))
        // Подгоняем под ширину: лучше чуть мельче, чем обрезать правый край.
        let cellSize = max(4, floor(raw * 10) / 10)
        let gridWidth = CGFloat(weekCount) * cellSize + gaps
        return (columns, bands, cellSize, gridWidth)
    }

    // MARK: - Private

    /// Месяц колонки: первый день недели, попадающий в окно [start, end].
    private static func monthAnchor(
        for week: [Date],
        windowStart: Date,
        windowEnd: Date,
        calendar: Calendar
    ) -> Date? {
        let start = calendar.startOfDay(for: windowStart)
        let end = calendar.startOfDay(for: windowEnd)
        if let inWindow = week.first(where: {
            let day = calendar.startOfDay(for: $0)
            return day >= start && day <= end
        }) {
            return inWindow
        }
        return week.first.map { calendar.startOfDay(for: $0) }
    }
}
