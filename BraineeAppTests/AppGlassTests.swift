//
//  AppGlassTests.swift
//  BraineeAppTests
//
//  Стекло (п. 60): когда включается, прозрачность карточек и её границы.

import Foundation
import Testing
@testable import BraineeApp

struct AppGlassTests {
    private func resolve(
        mode: AppBackgroundMode = .image,
        hasImage: Bool = true,
        enabled: Bool = true,
        level: Double = 0.5,
        reduceTransparency: Bool = false
    ) -> GlassAppearance {
        GlassAppearance.resolve(
            mode: mode, hasImage: hasImage, enabled: enabled,
            level: level, reduceTransparency: reduceTransparency
        )
    }

    // Стекло только при активном фоне, включённой настройке и без «Понижения прозрачности».
    @Test func стеклоВыключено_безФонаКартинкиНастройкиИлиПриПониженииПрозрачности() {
        #expect(resolve(mode: .none) == .off)
        #expect(resolve(hasImage: false) == .off)
        #expect(resolve(enabled: false) == .off)
        #expect(resolve(reduceTransparency: true) == .off)
    }

    // Включено: кнопки стеклянные, карточки — по ползунку.
    @Test func стеклоВключено_кнопкиИКарточкиПоПолзунку() {
        let glass = resolve(level: 0.5)
        #expect(glass.controls)
        #expect(glass.cardsAreGlass)
        #expect(abs(glass.cardFillOpacity - 0.59) < 0.0001)
    }

    // 0 % — стеклянные только кнопки и панель, карточки непрозрачные, как раньше.
    @Test func нольПроцентов_карточкиНепрозрачные() {
        let glass = resolve(level: 0)
        #expect(glass.controls)
        #expect(!glass.cardsAreGlass)
        #expect(glass.cardFillOpacity == 1)
        #expect(GlassAppearance.off.cardFillOpacity == 1)
    }

    // 100 % — у карточки остаётся 18 % её цвета; значения вне 0…100 % обрезаются.
    @Test func границыПрозрачности() throws {
        #expect(abs(resolve(level: 1).cardFillOpacity - 0.18) < 0.0001)
        #expect(resolve(level: 1.7).cardTransparency == 1)
        #expect(resolve(level: -0.3).cardTransparency == 0)
        #expect(AppGlassSettings.clampedLevel(.nan) == 0)
        #expect(AppGlassSettings.percentText(1) == "100 %")
        #expect(AppGlassSettings.percentText(0.35) == "35 %")

        let defaults = try #require(UserDefaults(suiteName: "AppGlassTests-\(UUID().uuidString)"))
        #expect(AppGlassSettings.level(defaults: defaults) == 0)
        defaults.set(2.0, forKey: AppGlassSettings.levelKey)
        #expect(AppGlassSettings.level(defaults: defaults) == 1)
    }
}
