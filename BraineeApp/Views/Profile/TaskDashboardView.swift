//
//  TaskDashboardView.swift
//  BraineeApp
//
//  Дашборд: моно-числа, геометрический прогресс-бар, строгая сетка.

import SwiftUI
import SwiftData

struct TaskDashboardView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isSoftDeleted })
    private var activeTasks: [TaskItem]

    var body: some View {
        Section {
            ForEach(TaskCategory.allCases) { category in
                let stats = TaskCategoryStats.compute(from: activeTasks, category: category)
                VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(category.title, systemImage: category.systemImage)
                            .font(DesignSystem.Typography.headline())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Text("\(stats.completed)/\(stats.total)")
                            .font(DesignSystem.Typography.data())
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }

                    PankinProgressBar(value: stats.progress)

                    HStack(spacing: DesignSystem.Space.x4) {
                        statBadge(title: "Активные", value: stats.active)
                        statBadge(title: "Просрочено", value: stats.overdue, emphasize: stats.overdue > 0)
                        statBadge(title: "Сегодня", value: stats.today)
                    }
                }
                .padding(.vertical, DesignSystem.Space.x1)
                .listRowBackground(DesignSystem.Colors.surface)
            }
        } header: {
            Text("Дашборд")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .textCase(nil)
        }
    }

    private func statBadge(title: String, value: Int, emphasize: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
            Text("\(value)")
                .font(DesignSystem.Typography.data(16))
                .foregroundStyle(emphasize ? DesignSystem.Colors.danger : DesignSystem.Colors.accent)
            Text(title)
                .font(DesignSystem.Typography.caption(10))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    Form {
        TaskDashboardView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
