//
//  DesignSystem.swift
//  BraineeApp
//
//  Дизайн-система в духе Александра Панкина: геометрия, сетка 4pt,
//  моноширинные заголовки, оранжевый акцент, минимум декора.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum DesignSystem {
    // MARK: - Сетка (всё кратно 4)

    enum Space {
        static let unit: CGFloat = 4

        static func grid(_ n: CGFloat) -> CGFloat { unit * n }

        static let x1 = grid(1)   // 4
        static let x2 = grid(2)   // 8
        static let x3 = grid(3)   // 12
        static let x4 = grid(4)   // 16
        static let x5 = grid(5)   // 20
        static let x6 = grid(6)   // 24
        static let x8 = grid(8)   // 32
        static let x10 = grid(10) // 40
        static let x11 = grid(11) // 44 — зона нажатия
    }

    // MARK: - Скругления

    enum Radius {
        /// Единственное допустимое скругление карточек и чипов.
        static let card: CGFloat = 4
        static let none: CGFloat = 0
    }

    // MARK: - Линии

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 2
    }

    // MARK: - Цвета (светлая / тёмная)

    enum Colors {
        /// Фон экрана (слегка серый в светлой теме — карточки читаются лучше).
        static let background = Color.pankinAdaptive(
            light: Color(hex: 0xF2F2F2),
            dark: Color(hex: 0x000000)
        )
        /// Карточки / панели — контраст к фону.
        static let surface = Color.pankinAdaptive(
            light: .white,
            dark: Color(hex: 0x1C1C1E)
        )
        /// Подложки чипов и бейджей внутри карточки.
        static let chip = Color.pankinAdaptive(
            light: Color(hex: 0xF2F2F2),
            dark: Color(hex: 0x2C2C2E)
        )
        static let accent = Color(hex: 0xFF6B00)
        static let textPrimary = Color.pankinAdaptive(
            light: .black,
            dark: .white
        )
        /// Вторичный текст с запасом контраста на серых подложках.
        static let textSecondary = Color.pankinAdaptive(
            light: Color(hex: 0x666666),
            dark: Color(hex: 0xA8A8A8)
        )
        static let divider = Color.pankinAdaptive(
            light: Color(hex: 0xE0E0E0),
            dark: Color(hex: 0x333333)
        )

        /// Просрочка / опасность — геометричный красный, не «мягкий» системный.
        static let danger = Color(hex: 0xD32F2F)
        /// Успех / выполнено — строгий тёмно-зелёный.
        static let success = Color(hex: 0x2E7D32)
    }

    // MARK: - Типографика

    enum Typography {
        /// Заголовки: моноширинный жирный — математическая точность.
        static func title(_ size: CGFloat = 20) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }

        static func headline(_ size: CGFloat = 16) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }

        /// Основной текст: San Francisco.
        static func body(_ size: CGFloat = 16) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func caption(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        /// Числа и данные: моно + акцент в UI.
        static func data(_ size: CGFloat = 14) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }

        static func tabLabel(_ size: CGFloat = 10) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
    }

    // MARK: - Иконки (линейный стиль)

    enum Icon {
        static let checkboxOff = "circle"
        static let checkboxOn = "checkmark.circle"
        static let folder = "folder"
        static let tray = "tray"
        static let calendar = "calendar"
        static let pencil = "pencil"
        static let trash = "trash"
        static let check = "checkmark"
        static let cancel = "xmark"
        static let person = "person"
        static let drag = "line.3.horizontal"
    }
}

// MARK: - Геометрические компоненты

/// Прогресс из прямоугольников (без «мягких» кривых ProgressView).
struct PankinProgressBar: View {
    var value: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DesignSystem.Colors.divider)
                Rectangle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: DesignSystem.Space.x1)
    }
}

/// Тонкий горизонтальный разделитель 1pt.
struct PankinDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.divider)
            .frame(height: DesignSystem.Stroke.hairline)
    }
}

/// Карточка: поверхность, скругление 4pt, без мягких теней.
struct PankinCardBackground: ViewModifier {
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                    .fill(DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
                    .strokeBorder(
                        isHighlighted ? DesignSystem.Colors.accent : DesignSystem.Colors.divider,
                        lineWidth: isHighlighted ? DesignSystem.Stroke.emphasis : DesignSystem.Stroke.hairline
                    )
            )
    }
}

extension View {
    func pankinCard(highlighted: Bool = false) -> some View {
        modifier(PankinCardBackground(isHighlighted: highlighted))
    }

    func pankinScreenBackground() -> some View {
        background(DesignSystem.Colors.background.ignoresSafeArea())
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Адаптивный цвет под светлую / тёмную тему.
    static func pankinAdaptive(light: Color, dark: Color) -> Color {
#if canImport(UIKit)
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(dark)
                    : UIColor(light)
            }
        )
#else
        light
#endif
    }
}
