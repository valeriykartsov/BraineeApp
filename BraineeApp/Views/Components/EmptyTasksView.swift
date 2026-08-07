//
//  EmptyTasksView.swift
//  BraineeApp
//
//  Заглушка, когда в разделе ещё нет ни одной задачи.

import SwiftUI

struct EmptyTasksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
            Text("Нет задач")
                .font(DesignSystem.Typography.title(22))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("Нажмите «+», чтобы добавить первую задачу")
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            PankinDivider()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Space.x4)
        .pankinScreenBackground()
    }
}
