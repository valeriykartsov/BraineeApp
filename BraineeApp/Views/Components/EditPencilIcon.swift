//
//  EditPencilIcon.swift
//  BraineeApp
//
//  Абстрактный толстый карандаш для кнопок редактирования (единый стиль).

import SwiftUI

/// Геометричный карандаш: толстый стержень под 45° и короткий наконечник.
struct EditPencilIcon: View {
    var size: CGFloat = DesignSystem.Icon.pencilSize
    var color: Color = DesignSystem.Colors.accent

    var body: some View {
        AbstractPencilShape()
            .fill(color, style: FillStyle(eoFill: false, antialiased: true))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Упрощённый силуэт: корпус + скошенный кончик, без деталей SF Symbol.
struct AbstractPencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let inset = s * 0.08
        let bounds = CGRect(
            x: rect.midX - s / 2 + inset,
            y: rect.midY - s / 2 + inset,
            width: s - inset * 2,
            height: s - inset * 2
        )

        // Локальные координаты: карандаш вдоль диагонали (как у иконки edit).
        // Толщина корпуса ~32% от стороны — заметно «жирнее» SF Symbol pencil.
        let thickness = bounds.width * 0.34
        let tipLength = bounds.width * 0.22

        // Ось от верхнего-правого к нижнему-левому.
        let start = CGPoint(x: bounds.maxX - thickness * 0.35, y: bounds.minY + thickness * 0.35)
        let tip = CGPoint(x: bounds.minX + tipLength * 0.15, y: bounds.maxY - tipLength * 0.15)

        let dx = tip.x - start.x
        let dy = tip.y - start.y
        let len = max(hypot(dx, dy), 0.001)
        let ux = dx / len
        let uy = dy / len
        // Перпендикуляр.
        let px = -uy
        let py = ux

        let half = thickness / 2
        // Конец корпуса перед наконечником.
        let bodyEnd = CGPoint(
            x: tip.x - ux * tipLength,
            y: tip.y - uy * tipLength
        )

        let p1 = CGPoint(x: start.x + px * half, y: start.y + py * half)
        let p2 = CGPoint(x: start.x - px * half, y: start.y - py * half)
        let p3 = CGPoint(x: bodyEnd.x - px * half, y: bodyEnd.y - py * half)
        let p4 = CGPoint(x: bodyEnd.x + px * half, y: bodyEnd.y + py * half)

        // Скос наконечника (два «фаса» к острию).
        let tipLeft = CGPoint(x: bodyEnd.x - px * half * 0.55, y: bodyEnd.y - py * half * 0.55)
        let tipRight = CGPoint(x: bodyEnd.x + px * half * 0.55, y: bodyEnd.y + py * half * 0.55)

        var path = Path()
        // Корпус со скруглённым «ластиком».
        path.move(to: p1)
        path.addLine(to: p4)
        path.addLine(to: tipRight)
        path.addLine(to: tip)
        path.addLine(to: tipLeft)
        path.addLine(to: p3)
        path.addLine(to: p2)
        path.closeSubpath()

        // Слегка скруглить визуально через отдельный круг на торце.
        let eraserRadius = half * 0.95
        path.addEllipse(in: CGRect(
            x: start.x - eraserRadius,
            y: start.y - eraserRadius,
            width: eraserRadius * 2,
            height: eraserRadius * 2
        ))

        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        EditPencilIcon(size: 16, color: .orange)
        EditPencilIcon(size: 20, color: .orange)
        EditPencilIcon(size: 28, color: .orange)
    }
    .padding()
}
