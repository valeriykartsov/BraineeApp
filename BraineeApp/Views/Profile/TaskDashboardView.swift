//
//  TaskDashboardView.swift
//  BraineeApp
//
//  Дашборд: один grouped-блок с прогрессом по Карьере / Спорту / Ментальному.

import SwiftUI
import SwiftData

struct TaskDashboardView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isSoftDeleted })
    private var activeTasks: [TaskItem]

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        GroupedSection(title: "Дашборд") {
            VStack(spacing: 0) {
                ForEach(Array(TaskCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    let stats = TaskCategoryStats.compute(from: activeTasks, category: category)
                    categoryBlock(category: category, stats: stats)
                    if index < TaskCategory.allCases.count - 1 {
                        InsetDivider(leading: DesignSystem.Space.x3)
                    }
                }
            }
        }
        .id(accentPaletteRaw) // принудительно обновляем цифры/полосы при смене акцента
    }

    private func categoryBlock(category: TaskCategory, stats: TaskCategoryStats) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            HStack(alignment: .firstTextBaseline) {
                Label(category.title, systemImage: category.systemImage)
                    .font(DesignSystem.Typography.headline(15))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer(minLength: DesignSystem.Space.x2)
                Text("\(stats.completed)/\(stats.total)")
                    .font(DesignSystem.Typography.display(22))
                    .monospaced()
                    .foregroundStyle(accentColor)
            }

            AppProgressBar(value: stats.progress)

            Text("Активные \(stats.active)  ·  Просрочено \(stats.overdue)  ·  Сегодня \(stats.today)")
                .font(DesignSystem.Typography.caption(11))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2 + 2)
    }
}

#Preview {
    ScrollView {
        TaskDashboardView()
            .groupedScreenPadding()
    }
    .appScreenBackground()
    .modelContainer(for: TaskItem.self, inMemory: true)
}
