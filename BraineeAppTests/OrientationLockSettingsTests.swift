//
//  OrientationLockSettingsTests.swift
//  BraineeAppTests
//
//  Фиксация вертикальной ориентации: значение по умолчанию и маска.

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import BraineeApp

struct OrientationLockSettingsTests {

    private func makeSuite() -> UserDefaults {
        let suiteName = "OrientationLockSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func поУмолчанию_фиксацияВключена() {
        // Без сохранённого ключа приложение держит вертикаль.
        let defaults = makeSuite()
        #expect(OrientationLockSettings.defaultLocked == true)
        #expect(OrientationLockSettings.isPortraitLocked(defaults: defaults) == true)
    }

    @Test func выключеннаяФиксация_читаетсяИзUserDefaults() {
        // Явно выключенный свитчер разрешает горизонталь.
        let defaults = makeSuite()
        defaults.set(false, forKey: OrientationLockSettings.lockPortraitKey)
        #expect(OrientationLockSettings.isPortraitLocked(defaults: defaults) == false)
    }

#if canImport(UIKit)
    @Test func маскаОриентаций_зависитОтФлага() {
        // Вкл → только portrait; выкл → все кроме upsideDown.
        let defaults = makeSuite()

        defaults.set(true, forKey: OrientationLockSettings.lockPortraitKey)
        #expect(OrientationLockSettings.supportedOrientations(defaults: defaults) == .portrait)

        defaults.set(false, forKey: OrientationLockSettings.lockPortraitKey)
        #expect(OrientationLockSettings.supportedOrientations(defaults: defaults) == .allButUpsideDown)
    }
#endif
}
