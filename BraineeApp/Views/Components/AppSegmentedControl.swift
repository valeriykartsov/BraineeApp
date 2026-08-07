//
//  AppSegmentedControl.swift
//  BraineeApp
//
//  Сегментный переключатель в стиле soft capsule.

import SwiftUI

struct AppSegmentedControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: DesignSystem.Space.x1) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(DesignSystem.Typography.caption(12))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : DesignSystem.Colors.textSecondary
                        )
                        .padding(.horizontal, DesignSystem.Space.x2)
                        .padding(.vertical, DesignSystem.Space.x2)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Space.x1)
        .background(
            Capsule(style: .continuous)
                .fill(DesignSystem.Colors.chip)
        )
    }
}
