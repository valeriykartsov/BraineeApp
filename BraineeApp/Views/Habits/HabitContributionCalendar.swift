//
//  HabitContributionCalendar.swift
//  BraineeApp
//
//  Сетка прогресса в стиле GitHub: текущая неделя справа, отступы между месяцами.

import SwiftUI

struct HabitContributionCalendar: View {
    let habits: [Habit]

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @State private var measuredWidth: CGFloat = 0

    private let cellGap: CGFloat = 3
    private let monthGap: CGFloat = 8
    private let labelColumnWidth: CGFloat = 22
    private let monthLabelHeight: CGFloat = 14
    private let minCell: CGFloat = 10

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    private var layoutHeight: CGFloat {
        let width = measuredWidth > 0 ? measuredWidth : 280
        let span = HabitProgress.weekSpan(
            forAvailableWidth: width,
            labelColumnWidth: labelColumnWidth,
            gap: cellGap,
            monthGap: monthGap,
            minCell: minCell
        )
        return monthLabelHeight + cellGap + 7 * span.cellSize + 6 * cellGap
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: layoutHeight)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: HabitCalendarWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(HabitCalendarWidthKey.self) { measuredWidth = $0 }
            .overlay(alignment: .topLeading) {
                if measuredWidth > 0 {
                    calendarGrid(width: measuredWidth)
                }
            }
            .clipped()
            .accessibilityLabel("Календарь прогресса привычек")
    }

    private func calendarGrid(width: CGFloat) -> some View {
        let span = HabitProgress.weekSpan(
            forAvailableWidth: width,
            labelColumnWidth: labelColumnWidth,
            gap: cellGap,
            monthGap: monthGap,
            minCell: minCell
        )
        let days = HabitProgress.contributionDays(
            weeksBefore: span.weeksBefore,
            weeksAfter: span.weeksAfter
        )
        let columns = HabitProgress.columns(from: days)
        let monthBoundaries = HabitProgress.monthBoundaryIndices(after: columns)
        let cellSize = span.cellSize
        let weekdayLabels = columns.first?.map { CalendarWeekHelper.weekdayShort($0) } ?? []
        let monthMarkers = Self.monthMarkers(for: columns)
        let columnOffsets = Self.columnOffsets(
            columnCount: columns.count,
            cellSize: cellSize,
            cellGap: cellGap,
            monthGap: monthGap,
            monthBoundaries: monthBoundaries
        )
        let gridWidth = (columnOffsets.last ?? 0) + cellSize

        return VStack(alignment: .leading, spacing: cellGap) {
            HStack(alignment: .center, spacing: cellGap) {
                Color.clear.frame(width: labelColumnWidth, height: monthLabelHeight)
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: gridWidth, height: monthLabelHeight)
                    ForEach(monthMarkers, id: \.index) { marker in
                        Text(marker.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .offset(x: columnOffsets[safe: marker.index] ?? 0)
                    }
                }
                .frame(width: min(gridWidth, width - labelColumnWidth - cellGap), alignment: .leading)
            }

            HStack(alignment: .top, spacing: cellGap) {
                VStack(spacing: cellGap) {
                    ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: labelColumnWidth, height: cellSize, alignment: .trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, week in
                        VStack(spacing: cellGap) {
                            ForEach(week, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(cellColor(for: day))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay {
                                        if Calendar.current.isDateInToday(day) {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .strokeBorder(accentColor, lineWidth: 1)
                                        }
                                    }
                            }
                        }

                        if columnIndex < columns.count - 1 {
                            Color.clear
                                .frame(
                                    width: monthBoundaries.contains(columnIndex) ? monthGap : cellGap,
                                    height: 1
                                )
                        }
                    }
                }
                .frame(width: min(gridWidth, width - labelColumnWidth - cellGap), alignment: .leading)
                .clipped()
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private static func columnOffsets(
        columnCount: Int,
        cellSize: CGFloat,
        cellGap: CGFloat,
        monthGap: CGFloat,
        monthBoundaries: Set<Int>
    ) -> [CGFloat] {
        var offsets: [CGFloat] = []
        var x: CGFloat = 0
        for index in 0..<columnCount {
            offsets.append(x)
            x += cellSize
            if index < columnCount - 1 {
                x += monthBoundaries.contains(index) ? monthGap : cellGap
            }
        }
        return offsets
    }

    private static func monthMarkers(for columns: [[Date]]) -> [(index: Int, label: String)] {
        var result: [(Int, String)] = []
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLL"

        for (index, week) in columns.enumerated() {
            guard let day = week.first else { continue }
            if index > 0, let previous = columns[index - 1].first,
               calendar.isDate(day, equalTo: previous, toGranularity: .month) {
                continue
            }
            let label = formatter.string(from: day).replacingOccurrences(of: ".", with: "")
            result.append((index, label))
        }
        return result
    }

    private func cellColor(for day: Date) -> Color {
        let today = Calendar.current.startOfDay(for: .now)
        let dayStart = Calendar.current.startOfDay(for: day)
        if dayStart > today {
            return DesignSystem.Colors.chip.opacity(0.35)
        }
        let ratio = HabitProgress.completionRatio(for: day, habits: habits)
        if habits.isEmpty || ratio <= 0 {
            return DesignSystem.Colors.chip
        }
        let opacity = 0.22 + (0.78 * ratio)
        return accentColor.opacity(opacity)
    }
}

private struct HabitCalendarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
