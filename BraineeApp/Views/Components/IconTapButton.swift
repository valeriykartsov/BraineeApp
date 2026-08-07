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
    /// Компактная зона нажатия — ближе соседние кнопки (например, edit/delete у тега).
    var compact: Bool = false
    let accessibilityLabel: String
    let action: () -> Void

    private var hitSize: CGFloat {
        compact ? DesignSystem.Space.x8 : DesignSystem.Space.x11
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(DesignSystem.Typography.body(compact ? 15 : 16))
                .fontWeight(.medium)
                .foregroundStyle(resolvedTint)
                .frame(minWidth: hitSize, minHeight: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private var resolvedTint: Color {
        if let tint { return tint }
        // Удаление тоже в акцентном цвете темы (не отдельный красный).
        return DesignSystem.Colors.accent
    }
}
