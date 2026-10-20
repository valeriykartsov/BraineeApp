//
//  AccentInstallDefaultsTests.swift
//  BraineeAppTests
//
//  Первая установка и повторный запуск: правила акцента через AppDataPersistence.applyAccentDefaults.

import Foundation
import Testing
@testable import BraineeApp

struct AccentInstallDefaultsTests {
    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AccentInstallDefaultsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    // После переустановки (нет маркера запуска) акцент сбрасывается на оранжевый и ставится маркер.
    @Test func свежаяУстановка_сбрасываетАкцентНаОранжевыйИПишетМаркер() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AccentPalette.blue.rawValue, forKey: AccentPalette.storageKey)

        AppDataPersistence.applyAccentDefaults(defaults: defaults)

        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.orange.rawValue)
        #expect(defaults.bool(forKey: AccentPalette.hasLaunchedStorageKey))
    }

    // Повторный запуск с уже выбранным акцентом не затирает цвет.
    @Test func повторныйЗапуск_неЗатираетВыбранныйАкцент() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
        defaults.set(AccentPalette.red.rawValue, forKey: AccentPalette.storageKey)

        AppDataPersistence.applyAccentDefaults(defaults: defaults)

        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.red.rawValue)
    }
}
