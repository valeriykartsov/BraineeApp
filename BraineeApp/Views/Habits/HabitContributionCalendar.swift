//
//  HabitContributionCalendar.swift
//  BraineeApp
//
//  Сетка прогресса: слева 2 предыдущих месяца, справа полный текущий.
//  Подписи месяцев по центру блока дней; календарь выровнен влево.

import SwiftUI

struct HabitContributionCalendar: View {
    let habits: [Habit]
    /// День, выбранный переключателем в разделе Привычки — подсвечивается в сетке.
    var selectedDay: Date = .now

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @State private var measuredWidth: CGFloat = 0

    private let cellGap: CGFloat = 3
    private let monthGap: CGFloat = 8
    private let labelColumnWidth: CGFloat = 22
    private let monthLabelHeight: CGFloat = 14
    private let minCell: CGFloat = 8

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    private var selectedDayStart: Date {
        Calendar.current.startOfDay(for: selectedDay)
    }

    private var layoutHeight: CGFloat {
        let width = measuredWidth > 0 ? measuredWidth : 280
        let layout = HabitProgress.cellSizeForThreeMonthWindow(
            availableWidth: width,
            labelColumnWidth: labelColumnWidth,
            gap: cellGap,
            monthGap: monthGap,
            minCell: minCell
        )
        return monthLabelHeight + cellGap + 7 * layout.cellSize + 6 * cellGap
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
            .accessibilityLabel("Календарь прогресса привычек")
    }

    private func calendarGrid(width: CGFloat) -> some View {
        let layout = HabitProgress.cellSizeForThreeMonthWindow(
            availableWidth: width,
            labelColumnWidth: labelColumnWidth,
            gap: cellGap,
            monthGap: monthGap,
            minCell: minCell
        )
        let columns = layout.columns
        let bands = layout.bands
        let cellSize = layout.cellSize
        let boundaries = Set(bands.dropLast().compactMap { band -> Int? in
            let last = band.columnEndExclusive - 1
            return last >= 0 ? last : nil
        })
        let columnOffsets = Self.columnOffsets(
            columnCount: columns.count,
            cellSize: cellSize,
            cellGap: cellGap,
            monthGap: monthGap,
            monthBoundaries: boundaries
        )
        let gridWidth = layout.gridWidth
        let weekdayLabels = columns.first?.map { CalendarWeekHelper.weekdayShort($0) } ?? []

        // Календарь слева в контейнере — без сдвига к правому краю.
        return VStack(alignment: .leading, spacing: cellGap) {
            HStack(alignment: .center, spacing: cellGap) {
                Color.clear.frame(width: labelColumnWidth, height: monthLabelHeight)
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: gridWidth, height: monthLabelHeight)
                    ForEach(Array(bands.enumerated()), id: \.element.columnStart) { _, band in
                        let startX = columnOffsets[safe: band.columnStart] ?? 0
                        let endX: CGFloat = {
                            if band.columnEndExclusive < columnOffsets.count {
                                return columnOffsets[band.columnEndExclusive]
                            }
                            return gridWidth
                        }()
                        let bandWidth = max(endX - startX, cellSize)
                        Text(band.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: bandWidth, alignment: .center)
                            .offset(x: startX)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
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
                                let dayStart = Calendar.current.startOfDay(for: day)
                                let isSelected = Calendar.current.isDate(dayStart, inSameDayAs: selectedDayStart)
                                let isToday = Calendar.current.isDateInToday(day)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(cellColor(for: day))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .strokeBorder(accentColor, lineWidth: 2)
                                        } else if isToday {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .strokeBorder(accentColor.opacity(0.55), lineWidth: 1)
                                        }
                                    }
                                    .overlay {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .fill(accentColor.opacity(0.18))
                                        }
                                    }
                            }
                        }

                        if columnIndex < columns.count - 1 {
                            Color.clear
                                .frame(
                                    width: boundaries.contains(columnIndex) ? monthGap : cellGap,
                                    height: 1
                                )
                        }
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
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
