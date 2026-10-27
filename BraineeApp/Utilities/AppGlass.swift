//
//  AppGlass.swift
//  BraineeApp
//
//  Стекло (Liquid Glass, п. 60): только над картинкой фона и только если включено «Стекло».
//  Кнопки шапок, сегмент и панель вкладок — стеклянные; карточки — по ползунку «Прозрачность элементов»
//  (0 % — как раньше). На iOS 26+ — `glassEffect`, на iOS 18 — материал. «Понижение прозрачности»
//  в настройках iPhone выключает стекло.

import SwiftUI

enum AppGlassSettings {
    static let enabledKey = "appGlassEnabled"
    static let levelKey = "appGlassLevel"

    static let defaultLevel = 0.0
    /// Карточка при 100 % ещё сохраняет 18 % своего цвета — текст не теряется на картинке.
    static let maxFillReduction = 0.82

    /// Прозрачность карточек в границах 0…100 %.
    static func clampedLevel(_ value: Double) -> Double {
        guard value.isFinite else { return defaultLevel }
        return min(max(value, 0), 1)
    }

    static func percentText(_ level: Double) -> String {
        "\(Int((clampedLevel(level) * 100).rounded())) %"
    }

    /// Прозрачность из UserDefaults: ключа нет — 0 %.
    static func level(defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: levelKey) != nil else { return defaultLevel }
        return clampedLevel(defaults.double(forKey: levelKey))
    }
}

/// Как выглядят элементы сейчас — считается один раз в корне и передаётся через окружение.
struct GlassAppearance: Equatable {
    /// Кнопки шапок, сегмент, панель вкладок, панель ввода чата — стеклянные.
    var controls: Bool
    /// Прозрачность карточек 0…1; 0 — непрозрачные, как раньше.
    var cardTransparency: Double

    static let off = GlassAppearance(controls: false, cardTransparency: 0)

    var cardsAreGlass: Bool { controls && cardTransparency > 0 }

    /// Насколько сохраняется собственный цвет карточки (1 — полностью).
    var cardFillOpacity: Double {
        cardsAreGlass ? 1 - cardTransparency * AppGlassSettings.maxFillReduction : 1
    }

    /// Стекло только при активном фоне (картинка выбрана и включена), включённой настройке
    /// и без системного «Понижения прозрачности».
    static func resolve(
        mode: AppBackgroundMode,
        hasImage: Bool,
        enabled: Bool,
        level: Double,
        reduceTransparency: Bool
    ) -> GlassAppearance {
        guard mode == .image, hasImage, enabled, !reduceTransparency else { return .off }
        return GlassAppearance(controls: true, cardTransparency: AppGlassSettings.clampedLevel(level))
    }
}

private struct GlassAppearanceKey: EnvironmentKey {
    static let defaultValue = GlassAppearance.off
}

extension EnvironmentValues {
    var appGlass: GlassAppearance {
        get { self[GlassAppearanceKey.self] }
        set { self[GlassAppearanceKey.self] = newValue }
    }
}

// MARK: - Модификаторы

/// Кнопка или переключатель: стекло, иначе — прежний вид (`solid` или без подложки).
private struct AppGlassControl<S: Shape>: ViewModifier {
    let shape: S
    let solid: Color?
    @Environment(\.appGlass) private var glass

    func body(content: Content) -> some View {
        if glass.controls {
            if #available(iOS 26.0, *) {
                // Без `.interactive()`: на капсуле с кнопками внутри интерактивное стекло забирало касания —
                // вкладки и прокрутка переставали откликаться (проверено в симуляторе iOS 27).
                content.glassEffect(.regular, in: shape)
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
        } else if let solid {
            content.background(shape.fill(solid))
        } else {
            content
        }
    }
}

/// Карточка: свой цвет с прозрачностью по ползунку поверх стекла; при 0 % — непрозрачный цвет, как раньше.
private struct AppCardSurface<S: Shape>: ViewModifier {
    let shape: S
    let fill: Color
    @Environment(\.appGlass) private var glass

    func body(content: Content) -> some View {
        if glass.cardsAreGlass {
            let tinted = content.background(shape.fill(fill.opacity(glass.cardFillOpacity)))
            if #available(iOS 26.0, *) {
                tinted.glassEffect(.regular, in: shape)
            } else {
                tinted.background(.ultraThinMaterial, in: shape)
            }
        } else {
            content.background(shape.fill(fill))
        }
    }
}

extension View {
    func appGlassControl<S: Shape>(in shape: S, solid: Color? = nil) -> some View {
        modifier(AppGlassControl(shape: shape, solid: solid))
    }

    func appCardSurface<S: Shape>(_ shape: S, fill: Color = DesignSystem.Colors.surface) -> some View {
        modifier(AppCardSurface(shape: shape, fill: fill))
    }
}
