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

    private func makeProfile(accent: AccentPalette) -> ProfileDocument {
        ProfileDocument(
            version: ProfileDocument.currentVersion,
            displayName: "Тест",
            avatarBase64: nil,
            age: 30,
            genderRaw: UserGender.male.rawValue,
            appThemeRaw: AppTheme.system.rawValue,
            accentPaletteRaw: accent.rawValue,
            createdAt: .now
        )
    }

    // После переустановки (нет маркера запуска) акцент сбрасывается на оранжевый,
    // даже если в profile/Keychain был другой цвет.
    @Test func свежаяУстановка_сбрасываетАкцентНаОранжевыйИПишетМаркер() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var profile = makeProfile(accent: .blue)
        let shouldSave = AppDataPersistence.applyAccentDefaults(to: &profile, defaults: defaults)

        #expect(shouldSave)
        #expect(profile.accentPaletteRaw == AccentPalette.orange.rawValue)
        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.orange.rawValue)
        #expect(defaults.bool(forKey: AccentPalette.hasLaunchedStorageKey))
    }

    // Повторный запуск с уже выбранным акцентом не затирает цвет.
    @Test func повторныйЗапуск_неЗатираетВыбранныйАкцент() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
        defaults.set(AccentPalette.red.rawValue, forKey: AccentPalette.storageKey)
        var profile = makeProfile(accent: .red)

        let shouldSave = AppDataPersistence.applyAccentDefaults(to: &profile, defaults: defaults)

        #expect(!shouldSave)
        #expect(profile.accentPaletteRaw == AccentPalette.red.rawValue)
        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.red.rawValue)
    }

    // Если маркер запуска есть, а ключа акцента в UserDefaults нет — берём из profile.json.
    @Test func повторныйЗапускБезКлючаАкцента_подтягиваетИзПрофиля() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AccentPalette.hasLaunchedStorageKey)
        var profile = makeProfile(accent: .aquamarine)

        let shouldSave = AppDataPersistence.applyAccentDefaults(to: &profile, defaults: defaults)

        #expect(!shouldSave)
        #expect(profile.accentPaletteRaw == AccentPalette.aquamarine.rawValue)
        #expect(defaults.string(forKey: AccentPalette.storageKey) == AccentPalette.aquamarine.rawValue)
    }
}
