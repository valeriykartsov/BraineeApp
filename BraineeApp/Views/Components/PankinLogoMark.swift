//
//  PankinLogoMark.swift
//  BraineeApp
//
//  Геометрический знак загрузки: квадраты и линии, цвета зависят от темы.

import SwiftUI

struct PankinLogoMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = DesignSystem.Space.grid(35) // 140

    private var lineColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let origin = CGPoint(
                x: (canvasSize.width - side) / 2,
                y: (canvasSize.height - side) / 2
            )
            let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
            let inset = side * 0.12
            let outer = rect.insetBy(dx: inset, dy: inset)
            let inner = rect.insetBy(dx: side * 0.32, dy: side * 0.32)
            let lineWidth = max(2, side * 0.035)

            // Три горизонтали
            for fraction in [0.32, 0.50, 0.68] as [CGFloat] {
                let y = rect.minY + side * fraction
                var path = Path()
                path.move(to: CGPoint(x: rect.minX + inset * 0.2, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - inset * 0.2, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
            }

            // Диагональ
            var diagonal = Path()
            diagonal.move(to: CGPoint(x: rect.minX + inset * 0.35, y: rect.maxY - inset * 0.35))
            diagonal.addLine(to: CGPoint(x: rect.maxX - inset * 0.35, y: rect.minY + inset * 0.35))
            context.stroke(diagonal, with: .color(lineColor), lineWidth: lineWidth)

            // Оранжевые квадраты поверх
            context.stroke(
                Path(outer),
                with: .color(DesignSystem.Colors.accent),
                lineWidth: lineWidth
            )
            context.stroke(
                Path(inner),
                with: .color(DesignSystem.Colors.accent),
                lineWidth: lineWidth
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
