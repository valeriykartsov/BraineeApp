//
//  TaskDashboardDetailView.swift
//  BraineeApp
//
//  Детализация дашборда: задачи по приоритетам и тегам.

import SwiftUI
import SwiftData

struct TaskDashboardDetailView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isSoftDeleted })
    private var activeTasks: [TaskItem]

    @Environment(\.dismiss) private var dismiss

    private var byPriority: [(TaskPriority, [TaskItem])] {
        TaskPriority.allCases.reversed().compactMap { priority in
            let items = activeTasks
                .filter { $0.priority == priority }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            guard !items.isEmpty else { return nil }
            return (priority, items)
        }
    }

    private var byTag: [(String, [TaskItem])] {
        var buckets: [String: [TaskItem]] = [:]
        var untagged: [TaskItem] = []
        for task in activeTasks {
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
                let items = (buckets[name] ?? []).sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return (name, items)
            }
        if !untagged.isEmpty {
            result.append(("Без тега", untagged.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Space.sectionGap) {
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
        Text("Нет активных задач")
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
                    Text(task.status.title)
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
