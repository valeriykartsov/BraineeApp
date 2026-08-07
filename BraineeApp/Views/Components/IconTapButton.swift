//
//  IconTapButton.swift
//  BraineeApp
//
//  Кнопка-иконка с удобной зоной нажатия (~44×44), чтобы легче попадать пальцем.

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
                .font(.body.weight(.medium))
                .foregroundStyle(resolvedTint)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private var resolvedTint: Color {
        if let tint { return tint }
        if role == .destructive { return .red }
        return .accentColor
    }
}
