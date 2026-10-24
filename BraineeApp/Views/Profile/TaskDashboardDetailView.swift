//
//  TaskDashboardDetailView.swift
//  BraineeApp
//
//  Детализация дашборда: сводка, доли тегов (круговая диаграмма), задачи по приоритетам и тегам.
//  Переключатель сверху: «Активные» (без корзины) или «Все» (включая удалённые).
//  В группах — сначала актуальные, затем выполненные, затем в корзине (`DashboardTaskOrder`).

import SwiftUI
import SwiftData
import Charts

struct TaskDashboardDetailView: View {
    /// Какие задачи учитывает экран. Выбор не сохраняется: экран всегда открывается на «Активных».
    enum Scope: String, CaseIterable, Identifiable {
        case active
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .active: "Активные"
            case .all: "Все"
            }
        }
    }

    /// Все задачи, включая корзину; отбор по переключателю — в `scopedTasks`.
    @Query private var allTasks: [TaskItem]

    @Environment(\.dismiss) private var dismiss
    @State private var scope: Scope = .active

    private var scopedTasks: [TaskItem] {
        scope == .active ? allTasks.notInTrash : allTasks
    }

    private var stats: TaskStats {
        TaskStats.compute(from: scopedTasks, includingTrash: scope == .all)
    }

    private var tagShares: [TagShare] {
        TagDistribution.compute(from: scopedTasks)
    }

    private var byPriority: [(TaskPriority, [TaskItem])] {
        TaskPriority.allCases.reversed().compactMap { priority in
            let items = DashboardTaskOrder.sorted(scopedTasks.filter { $0.priority == priority })
            guard !items.isEmpty else { return nil }
            return (priority, items)
        }
    }

    private var byTag: [(String, [TaskItem])] {
        var buckets: [String: [TaskItem]] = [:]
        var untagged: [TaskItem] = []
        for task in scopedTasks {
            if task.tags.isEmpty {
                untagged.append(task)
            } else {
                for tag in task.tags {
                    buckets[tag.name, default: []].append(task)
                }
            }
        }
        var result = buckets.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { name -> (String, [TaskItem]) in
                (name, DashboardTaskOrder.sorted(buckets[name] ?? []))
            }
        if !untagged.isEmpty {
            result.append((TagDistribution.untaggedName, DashboardTaskOrder.sorted(untagged)))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Space.sectionGap) {
                    Picker("Задачи", selection: $scope) {
                        ForEach(Scope.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    summarySection
                    tagChartSection
                    prioritySection
                    tagsSection
                }
                .groupedScreenPadding()
                .padding(.vertical, DesignSystem.Space.x3)
            }
            .appScreenBackground()
            .navigationTitle("Дашборд")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .tint(DesignSystem.Colors.accent)
        }
    }

    private var summarySection: some View {
        let stats = stats
        let trashed = scope == .all ? allTasks.count - allTasks.notInTrash.count : 0
        return GroupedSection(title: "Сводка") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Выполнено")
                        .font(DesignSystem.Typography.headline(15))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer(minLength: DesignSystem.Space.x2)
                    Text("\(stats.completed)/\(stats.total)")
                        .font(DesignSystem.Typography.display(22))
                        .monospaced()
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                AppProgressBar(value: stats.progress)
                Text(summaryLine(stats, trashed: trashed))
                    .font(DesignSystem.Typography.caption(11))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
        }
    }

    private func summaryLine(_ stats: TaskStats, trashed: Int) -> String {
        var parts = ["Активные \(stats.active)", "Просрочено \(stats.overdue)", "Сегодня \(stats.today)"]
        if scope == .all {
            parts.append("В корзине \(trashed)")
        }
        return parts.joined(separator: "  ·  ")
    }

    private var tagChartSection: some View {
        let shares = tagShares
        return GroupedSection(title: "Доли тегов") {
            if shares.isEmpty {
                emptyRow
            } else {
                VStack(spacing: DesignSystem.Space.x3) {
                    Chart(Array(shares.enumerated()), id: \.element.id) { index, share in
                        SectorMark(
                            angle: .value("Задачи", share.count),
                            angularInset: 1.5
                        )
                        .cornerRadius(3)
                        .foregroundStyle(sliceColor(share, index: index))
                        .accessibilityLabel(share.name)
                        .accessibilityValue("\(share.percent)%")
                    }
                    .chartLegend(.hidden)
                    .frame(height: 180)

                    VStack(spacing: DesignSystem.Space.x2) {
                        ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                            legendRow(share, color: sliceColor(share, index: index))
                        }
                    }
                }
                .padding(DesignSystem.Space.x3)
            }
        }
    }

    private func legendRow(_ share: TagShare, color: Color) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(share.name)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: DesignSystem.Space.x2)
            Text("\(share.count)")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text("\(share.percent)%")
                .font(DesignSystem.Typography.headline(15))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// Первый сектор — цвет акцента, дальше — остальные цвета палитры по кругу; «Без тега» — серый.
    private func sliceColor(_ share: TagShare, index: Int) -> Color {
        if share.isUntagged { return AccentPalette.gray.color }
        let accent = AccentPalette.current
        let others = Self.slicePalette.filter { $0 != accent }
        return index == 0 ? accent.color : others[(index - 1) % others.count].color
    }

    private static let slicePalette: [AccentPalette] = [
        .orange, .blue, .acidGreen, .yellow, .red, .lightBlue, .aquamarine, .darkGreen
    ]

    private var prioritySection: some View {
        GroupedSection(title: "По приоритетам") {
            if byPriority.isEmpty {
                emptyRow
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(byPriority.enumerated()), id: \.element.0.id) { index, pair in
                        detailBlock(
                            title: pair.0.title,
                            subtitle: "\(pair.1.count)",
                            titleColor: PriorityStyle.color(for: pair.0),
                            tasks: pair.1
                        )
                        if index < byPriority.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.x3)
                        }
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        GroupedSection(title: "По тегам") {
            if byTag.isEmpty {
                emptyRow
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(byTag.enumerated()), id: \.element.0) { index, pair in
                        detailBlock(
                            title: pair.0,
                            subtitle: "\(pair.1.count)",
                            titleColor: DesignSystem.Colors.textPrimary,
                            tasks: pair.1
                        )
                        if index < byTag.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.x3)
                        }
                    }
                }
            }
        }
    }

    private var emptyRow: some View {
        Text(scope == .active ? "Нет активных задач" : "Нет задач")
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Space.x4)
    }

    private func detailBlock(
        title: String,
        subtitle: String,
        titleColor: Color,
        tasks: [TaskItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.headline(15))
                    .foregroundStyle(titleColor)
                Spacer()
                Text(subtitle)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            ForEach(tasks, id: \.uuid) { task in
                HStack(spacing: DesignSystem.Space.x2) {
                    Circle()
                        .fill(task.isCompleted ? DesignSystem.Colors.accent : DesignSystem.Colors.chip)
                        .frame(width: 8, height: 8)
                    Text(task.title)
                        .font(DesignSystem.Typography.body(15))
                        .foregroundStyle(
                            task.isCompleted
                                ? DesignSystem.Colors.textSecondary
                                : DesignSystem.Colors.textPrimary
                        )
                        .strikethrough(task.isCompleted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(task.isSoftDeleted ? "В корзине" : task.status.title)
                        .font(DesignSystem.Typography.caption(11))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x3)
    }
}

#Preview {
    TaskDashboardDetailView()
        .modelContainer(for: [TaskItem.self, TaskTag.self], inMemory: true)
}
