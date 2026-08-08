//
//  TaskDashboardView.swift
//  BraineeApp
//
//  Дашборд: прогресс по всем задачам; тап открывает детализацию.

import SwiftUI
import SwiftData

struct TaskDashboardView: View {
    @Query(filter: #Predicate<TaskItem> { !$0.isSoftDeleted })
    private var activeTasks: [TaskItem]

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @State private var showingDetail = false

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        let stats = TaskStats.compute(from: activeTasks)
        GroupedSection(title: "Дашборд") {
            Button {
                showingDetail = true
            } label: {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Все задачи", systemImage: "checklist")
                            .font(DesignSystem.Typography.headline(15))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer(minLength: DesignSystem.Space.x2)
                        Text("\(stats.completed)/\(stats.total)")
                            .font(DesignSystem.Typography.display(22))
                            .monospaced()
                            .foregroundStyle(accentColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    AppProgressBar(value: stats.progress)

                    Text("Активные \(stats.active)  ·  Просрочено \(stats.overdue)  ·  Сегодня \(stats.today)")
                        .font(DesignSystem.Typography.caption(11))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2 + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.15), value: accentPaletteRaw)
        .sheet(isPresented: $showingDetail) {
            TaskDashboardDetailView()
        }
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
