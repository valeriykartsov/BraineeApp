//
//  EmptyTasksView.swift
//  BraineeApp
//
//  Заглушка пустого раздела в grouped-стиле.

import SwiftUI

struct EmptyTasksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x6) {
            GroupedSection(title: "Задачи") {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                    Text("Нет задач")
                        .font(DesignSystem.Typography.headline())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Нажмите «+», чтобы добавить первую задачу")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Space.x4)
            }
        }
        .groupedScreenPadding()
        .padding(.vertical, DesignSystem.Space.x4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenBackground()
    }
}
