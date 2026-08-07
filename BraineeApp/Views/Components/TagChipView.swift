//
//  TagChipView.swift
//  BraineeApp
//
//  Чип тега: мягкая капсула без жёсткой обводки.

import SwiftUI

struct TagChipView: View {
    let name: String
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    chipLabel
                }
                .buttonStyle(.plain)
            } else {
                chipLabel
            }
        }
    }

    private var chipLabel: some View {
        Text(name)
            .font(DesignSystem.Typography.caption(13))
            .fontWeight(.medium)
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? DesignSystem.Colors.accent.opacity(0.18)
                            : DesignSystem.Colors.chip
                    )
            )
            .foregroundStyle(
                isSelected
                    ? DesignSystem.Colors.accent
                    : DesignSystem.Colors.textPrimary
            )
    }
}

/// Раскладывает теги в несколько строк, как перенос слов в тексте.
struct TagFlowLayout: Layout {
    var spacing: CGFloat = DesignSystem.Space.x1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
