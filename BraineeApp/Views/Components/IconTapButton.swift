//
//  IconTapButton.swift
//  BraineeApp
//
//  Кнопка-иконка с удобной зоной нажатия (~44×44) в стиле дизайн-системы.

import SwiftUI

struct IconTapButton: View {
    let systemName: String
    var role: ButtonRole? = nil
    var tint: Color? = nil
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(DesignSystem.Typography.body(16))
                .fontWeight(.medium)
                .foregroundStyle(resolvedTint)
                .frame(minWidth: DesignSystem.Space.x11, minHeight: DesignSystem.Space.x11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private var resolvedTint: Color {
        if let tint { return tint }
        if role == .destructive { return DesignSystem.Colors.danger }
        return DesignSystem.Colors.accent
    }
}
