//
//  TaskDashboardView.swift
//  BraineeApp
//
//  Сводка по разделам: сколько задач выполнено, просрочено и запланировано на сегодня.

import SwiftUI
import SwiftData

struct TaskDashboardView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isDeleted })
    private var activeTasks: [TaskItem]

    var body: some View {
        Section("Дашборд") {
            ForEach(TaskCategory.allCases) { category in
                let stats = TaskCategoryStats.compute(from: activeTasks, category: category)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.headline)
                        Spacer()
                        Text("\(stats.completed)/\(stats.total)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: stats.progress)
                        .tint(progressColor(for: category))

                    HStack(spacing: 16) {
                        statBadge(title: "Активные", value: stats.active, color: .blue)
                        statBadge(title: "Просрочено", value: stats.overdue, color: .red)
                        statBadge(title: "Сегодня", value: stats.today, color: .orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statBadge(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func progressColor(for category: TaskCategory) -> Color {
        switch category {
        case .career: .blue
        case .sport: .green
        case .mental: .purple
        }
    }
}

#Preview {
    Form {
        TaskDashboardView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
