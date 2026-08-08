//
//  DesignSystem.swift
//  BraineeApp
//
//  Дизайн-система: inset-grouped UI + оранжевый акцент Brainee.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum DesignSystem {
    // MARK: - Сетка (кратно 4)

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

        /// Горизонтальный отступ экрана до карточек (чуть уже).
        static let screenInset = x3
        /// Отступ до текста после иконки (padding x3 + icon x5 + spacing x2).
        static let rowIconInset = grid(10) // 40
        /// Отступ между папками / секциями профиля.
        static let sectionGap = x3
    }

    // MARK: - Скругления

    enum Radius {
        static let group: CGFloat = 16
        static let card: CGFloat = 12
        static let capsule: CGFloat = 999
        static let none: CGFloat = 0
    }

    // MARK: - Линии

    enum Stroke {
        static let hairline: CGFloat = 1 / 3
        static let regular: CGFloat = 1
        static let emphasis: CGFloat = 2
    }

    // MARK: - Цвета

    enum Colors {
        static let background = Color.themeAdaptive(
            light: Color(hex: 0xF2F2F7),
            dark: Color(hex: 0x000000)
        )
        static let surface = Color.themeAdaptive(
            light: .white,
            dark: Color(hex: 0x1C1C1E)
        )
        static let chip = Color.themeAdaptive(
            light: Color(hex: 0xE5E5EA),
            dark: Color(hex: 0x2C2C2E)
        )
        /// Акцент из выбранной палитры (по умолчанию оранжевый).
        static var accent: Color { AccentPalette.current.color }
        static let textPrimary = Color.themeAdaptive(
            light: .black,
            dark: .white
        )
        static let textSecondary = Color.themeAdaptive(
            light: Color(hex: 0x8E8E93),
            dark: Color(hex: 0x8E8E93)
        )
        static let divider = Color.themeAdaptive(
            light: Color(hex: 0xC6C6C8),
            dark: Color(hex: 0x38383A)
        )
        static let danger = Color(hex: 0xD32F2F)
        static let success = Color(hex: 0x2E7D32)
    }

    // MARK: - Типографика

    enum Typography {
        static func title(_ size: CGFloat = 20) -> Font {
            .system(size: size, weight: .bold, design: .default)
        }

        static func headline(_ size: CGFloat = 17) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }

        static func body(_ size: CGFloat = 17) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func bodyBold(_ size: CGFloat = 17) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }

        static func sectionHeader(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func caption(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func data(_ size: CGFloat = 14) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }

        static func display(_ size: CGFloat = 40) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }

        static func tabLabel(_ size: CGFloat = 9) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }
    }

    // MARK: - Иконки

    enum Icon {
        static let checkboxOff = "circle"
        static let checkboxOn = "checkmark.circle.fill"
        static let folder = "folder"
        static let tray = "tray"
        static let calendar = "calendar"
        /// Ключ для IconTapButton: рисуется абстрактный EditPencilIcon, не SF Symbol.
        static let pencil = "pencil"
        static let pencilSize: CGFloat = 18
        static let pencilSizeCompact: CGFloat = 17
        static let trash = "trash"
        static let check = "checkmark"
        static let cancel = "xmark"
        static let person = "person"
        static let drag = "line.3.horizontal"
        static let search = "magnifyingglass"
        static let paintbrush = "paintbrush"
        static let tag = "tag"
        static let chart = "chart.bar"
        static let storage = "externaldrive"
    }
}

// MARK: - Базовые компоненты

struct AppProgressBar: View {
    var value: Double
    /// Следим за палитрой, чтобы полоса перекрашивалась сразу после выбора акцента.
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DesignSystem.Colors.chip)
                Capsule(style: .continuous)
                    .fill(accentColor)
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? DesignSystem.Space.x2 : 0))
            }
        }
        .frame(height: DesignSystem.Space.x1)
        .animation(.easeInOut(duration: 0.2), value: accentPaletteRaw)
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.divider.opacity(0.55))
            .frame(height: DesignSystem.Stroke.regular)
    }
}

struct InsetDivider: View {
    var leading: CGFloat = DesignSystem.Space.rowIconInset

    var body: some View {
        AppDivider()
            .padding(.leading, leading)
    }
}

struct FlatHighlightBackground: ViewModifier {
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content.background(
            DesignSystem.Colors.accent.opacity(isHighlighted ? 0.10 : 0)
        )
    }
}

extension View {
    func flatHighlight(highlighted: Bool = false) -> some View {
        modifier(FlatHighlightBackground(isHighlighted: highlighted))
    }

    func appScreenBackground() -> some View {
        background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    func groupedCardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
                .fill(DesignSystem.Colors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous))
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

    static func themeAdaptive(light: Color, dark: Color) -> Color {
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
