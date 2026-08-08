//
//  OrientationLockSettings.swift
//  BraineeApp
//
//  Фиксация вертикальной ориентации: приоритет над системным поворотом экрана.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum OrientationLockSettings {
    /// Включено — только вертикаль; выключено — можно горизонталь.
    static let lockPortraitKey = "orientationLockPortrait"

    /// По умолчанию положение зафиксировано (вертикаль).
    static let defaultLocked = true

    static func isPortraitLocked(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: lockPortraitKey) == nil {
            return defaultLocked
        }
        return defaults.bool(forKey: lockPortraitKey)
    }

    /// Совместимость с прежним API без аргументов.
    static var isPortraitLocked: Bool {
        isPortraitLocked(defaults: .standard)
    }

#if canImport(UIKit)
    static func supportedOrientations(defaults: UserDefaults = .standard) -> UIInterfaceOrientationMask {
        isPortraitLocked(defaults: defaults) ? .portrait : .allButUpsideDown
    }

    static var supportedOrientations: UIInterfaceOrientationMask {
        supportedOrientations(defaults: .standard)
    }

    /// Применяет маску и при необходимости принудительно ставит портрет.
    @MainActor
    static func apply(lockPortrait: Bool, defaults: UserDefaults = .standard) {
        defaults.set(lockPortrait, forKey: lockPortraitKey)
        guard lockPortrait else { return }
        forcePortraitIfNeeded(defaults: defaults)
    }

    @MainActor
    static func forcePortraitIfNeeded(defaults: UserDefaults = .standard) {
        guard isPortraitLocked(defaults: defaults) else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(geometry) { _ in }
            scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }
#endif
}
