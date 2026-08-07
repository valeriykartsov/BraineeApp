//
//  AccentPaletteTests.swift
//  BraineeAppTests
//
//  Палитра акцента: дефолт и безопасный resolve.

import Testing
@testable import BraineeApp

struct AccentPaletteTests {
    // Неизвестное значение из JSON даёт оранжевый по умолчанию.
    @Test func неизвестныйАкцент_resolveВозвращаетОранжевый() {
        #expect(AccentPalette.resolved(from: nil) == .orange)
        #expect(AccentPalette.resolved(from: "unknown") == .orange)
    }

    // Все заявленные цвета доступны в палитре.
    @Test func палитраСодержитОранжевыйИДополнительныеЦвета() {
        let raws = Set(AccentPalette.allCases.map(\.rawValue))
        #expect(raws.contains("orange"))
        #expect(raws.contains("acidGreen"))
        #expect(raws.contains("aquamarine"))
        #expect(AccentPalette.allCases.count == 9)
    }

    // Оранжевый — основная иконка; кислотно-зелёный — AppIcon-green; остальные — AppIcon-<rawValue>.
    @Test func имяИконкиДляАкцента_соответствуетПалитре() {
        #expect(AccentPalette.orange.alternateIconName == nil)
        #expect(AppIconSwitcher.iconName(for: .orange) == nil)
        #expect(AccentPalette.blue.alternateIconName == "AppIcon-blue")
        #expect(AccentPalette.acidGreen.alternateIconName == "AppIcon-green")
        #expect(AccentPalette.aquamarine.alternateIconName == "AppIcon-aquamarine")
        #expect(AccentPalette.darkGreen.alternateIconName == "AppIcon-darkGreen")

        for palette in AccentPalette.allCases where palette != .orange && palette != .acidGreen {
            #expect(palette.alternateIconName == "AppIcon-\(palette.rawValue)")
        }
    }

    // Маркер первой установки помогает сбросить акцент на оранжевый после переустановки.
    @Test func ключПервогоЗапуска_заданИОтличаетсяОтКлючаАкцента() {
        #expect(!AccentPalette.hasLaunchedStorageKey.isEmpty)
        #expect(AccentPalette.hasLaunchedStorageKey != AccentPalette.storageKey)
    }

    // У всех цветов кроме оранжевого есть alternate icon; имена уникальны.
    @Test func alternateIconNames_уникальныИЗаданыДляВсехКромеОранжевого() {
        let names = AccentPalette.allCases.compactMap(\.alternateIconName)
        #expect(names.count == AccentPalette.allCases.count - 1)
        #expect(Set(names).count == names.count)
        #expect(names.contains("AppIcon-green"))
        #expect(!names.contains("AppIcon-orange"))
        #expect(!names.contains("AppIcon-acidGreen"))
    }

    // Подписи палитры на русском — для списка в профиле.
    @Test func titleДляВсехCases_непустыеНаРусском() {
        for palette in AccentPalette.allCases {
            #expect(!palette.title.isEmpty)
        }
        #expect(AccentPalette.orange.title == "Оранжевый")
        #expect(AccentPalette.acidGreen.title == "Кислотно-зелёный")
    }

    // Smoke: исходы смены иконки сравниваются корректно.
    @Test func appIconChangeOutcome_equatable() {
        #expect(AppIconSwitcher.ChangeOutcome.changed == .changed)
        #expect(AppIconSwitcher.ChangeOutcome.unchanged != .failed)
        #expect(AppIconSwitcher.ChangeOutcome.unsupported != .changed)
    }
}
