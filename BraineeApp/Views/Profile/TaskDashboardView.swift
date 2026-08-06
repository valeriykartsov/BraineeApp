//
//  TaskDashboardView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData

struct TaskDashboardView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isDeleted })
    private var activeTasks: [TaskItem]

    var body: some View {
        Section("Дашборд") {
            ForEach(TaskCategory.allCases) { category in
                let stats = stats(for: category)
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

    private func stats(for category: TaskCategory) -> CategoryStats {
        let tasks = activeTasks.filter { $0.category == category }
        let completed = tasks.filter(\.isCompleted).count
        let overdue = tasks.filter(\.isOverdue).count
        let today = tasks.filter(\.isDueToday).count
        let total = tasks.count
        let active = tasks.filter { !$0.isCompleted }.count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)
        return CategoryStats(total: total, completed: completed, active: active, overdue: overdue, today: today, progress: progress)
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

private struct CategoryStats {
    let total: Int
    let completed: Int
    let active: Int
    let overdue: Int
    let today: Int
    let progress: Double
}

#Preview {
    Form {
        TaskDashboardView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
