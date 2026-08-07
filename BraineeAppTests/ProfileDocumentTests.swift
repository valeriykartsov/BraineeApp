//
//  ProfileDocumentTests.swift
//  BraineeAppTests
//
//  Проверяем обратную совместимость profile.json и поля возраст/пол/акцент.

import Foundation
import Testing
@testable import BraineeApp

struct ProfileDocumentTests {
    // Старый profile.json без age/gender/accent должен читаться с значениями по умолчанию.
    @Test func старыйПрофильБезВозрастаИПола_декодируетсяСДефолтами() throws {
        let json = """
        {
          "version": 1,
          "displayName": "Валера",
          "avatarBase64": null,
          "appThemeRaw": "system",
          "createdAt": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ProfileDocument.self, from: json)
        document.normalize()

        #expect(document.displayName == "Валера")
        #expect(document.age == nil)
        #expect(document.genderRaw == UserGender.unspecified.rawValue)
        #expect(document.accentPaletteRaw == AccentPalette.orange.rawValue)
        #expect(document.version == ProfileDocument.currentVersion)
    }

    // Новый профиль с возрастом и полом сохраняет значения после normalize.
    @Test func профильСВозрастомИПолом_normalizeСохраняетКорректныеЗначения() {
        var document = ProfileDocument(
            version: 1,
            displayName: "  Анна  ",
            avatarBase64: nil,
            age: 28,
            genderRaw: UserGender.female.rawValue,
            appThemeRaw: AppTheme.system.rawValue,
            accentPaletteRaw: AccentPalette.blue.rawValue,
            createdAt: .now
        )
        document.normalize()

        #expect(document.displayName == "Анна")
        #expect(document.age == 28)
        #expect(document.genderRaw == UserGender.female.rawValue)
        #expect(document.accentPaletteRaw == AccentPalette.blue.rawValue)
    }

    // Некорректный возраст и неизвестный пол сбрасываются.
    @Test func некорректныеВозрастИПол_сбрасываютсяПриNormalize() {
        var document = ProfileDocument(
            version: 1,
            displayName: "Тест",
            avatarBase64: nil,
            age: 999,
            genderRaw: "unknown",
            appThemeRaw: AppTheme.system.rawValue,
            accentPaletteRaw: "unknown",
            createdAt: .now
        )
        document.normalize()

        #expect(document.age == nil)
        #expect(document.genderRaw == UserGender.unspecified.rawValue)
        #expect(document.accentPaletteRaw == AccentPalette.orange.rawValue)
    }

    // Граничные возрасты 1 и 120 валидны; 0 и 121 сбрасываются.
    @Test func возрастГраницы_1И120Сохраняются_0И121Сбрасываются() {
        var okLow = ProfileDocument(
            version: 3,
            displayName: "A",
            avatarBase64: nil,
            age: 1,
            genderRaw: UserGender.male.rawValue,
            appThemeRaw: AppTheme.system.rawValue,
            accentPaletteRaw: AccentPalette.orange.rawValue,
            createdAt: .now
        )
        okLow.normalize()
        #expect(okLow.age == 1)

        var okHigh = okLow
        okHigh.age = 120
        okHigh.normalize()
        #expect(okHigh.age == 120)

        var badLow = okLow
        badLow.age = 0
        badLow.normalize()
        #expect(badLow.age == nil)

        var badHigh = okLow
        badHigh.age = 121
        badHigh.normalize()
        #expect(badHigh.age == nil)
    }

    // encode/decode сохраняет акцент, возраст и пол.
    @Test func encodeDecode_сохраняетAccentAgeGender() throws {
        let original = ProfileDocument(
            version: ProfileDocument.currentVersion,
            displayName: "Валера",
            avatarBase64: nil,
            age: 27,
            genderRaw: UserGender.male.rawValue,
            appThemeRaw: AppTheme.dark.rawValue,
            accentPaletteRaw: AccentPalette.aquamarine.rawValue,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProfileDocument.self, from: data)

        #expect(decoded.displayName == "Валера")
        #expect(decoded.age == 27)
        #expect(decoded.genderRaw == UserGender.male.rawValue)
        #expect(decoded.accentPaletteRaw == AccentPalette.aquamarine.rawValue)
        #expect(decoded.appThemeRaw == AppTheme.dark.rawValue)
    }
}
