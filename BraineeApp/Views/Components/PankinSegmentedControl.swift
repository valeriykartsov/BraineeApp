//
//  PankinSegmentedControl.swift
//  BraineeApp
//
//  Геометричный переключатель сегментов в стиле дизайн-системы (без «системной» капсулы).

import SwiftUI

struct PankinSegmentedControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(DesignSystem.Typography.data(10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : DesignSystem.Colors.textPrimary
                        )
                        .padding(.horizontal, DesignSystem.Space.x2)
                        .padding(.vertical, DesignSystem.Space.x1)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.surface
                        )
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider)
                        .frame(width: DesignSystem.Stroke.hairline)
                }
            }
        }
        .background(DesignSystem.Colors.surface)
        .overlay {
            Rectangle()
                .strokeBorder(DesignSystem.Colors.divider, lineWidth: DesignSystem.Stroke.hairline)
        }
    }
}
