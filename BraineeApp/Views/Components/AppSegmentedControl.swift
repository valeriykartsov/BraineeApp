//
//  AppSegmentedControl.swift
//  BraineeApp
//
//  Компактный сегментный переключатель: капсула «перетекает» к выбранному пункту.

import SwiftUI

struct AppSegmentedControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    @Namespace private var selectionNamespace
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    private var flowAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option
                Button {
                    guard selection != option else { return }
                    withAnimation(flowAnimation) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(DesignSystem.Typography.caption(12))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Space.x3)
                        .padding(.vertical, DesignSystem.Space.x2)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(accentColor)
                                    .matchedGeometryEffect(id: "segmentThumb", in: selectionNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Space.x1)
        .background(
            Capsule(style: .continuous)
                .fill(DesignSystem.Colors.chip)
        )
        // Ширина по содержимому — не растягивается на всю строку.
        .fixedSize(horizontal: true, vertical: false)
    }
}
