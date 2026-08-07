//
//  AppIconSwitcher.swift
//  BraineeApp
//
//  Смена иконки приложения под выбранный акцентный цвет (Alternate App Icons).

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AppIconSwitcher {
    /// Результат попытки сменить иконку.
    enum ChangeOutcome: Equatable {
        case changed
        case unchanged
        case unsupported
        case failed
    }

    /// Имя alternate icon для палитры; `nil` — основная иконка (оранжевый).
    static func iconName(for palette: AccentPalette) -> String? {
        palette.alternateIconName
    }

    /// Синхронизирует иконку с текущим акцентом без UI-алертов (старт приложения).
    @MainActor
    static func syncWithCurrentAccent() {
        apply(for: .current, completion: { _ in })
    }

    /// Меняет иконку приложения под палитру.
    @MainActor
    static func apply(
        for palette: AccentPalette,
        completion: @escaping (ChangeOutcome) -> Void
    ) {
#if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            completion(.unsupported)
            return
        }

        let target = iconName(for: palette)
        if UIApplication.shared.alternateIconName == target {
            completion(.unchanged)
            return
        }

        UIApplication.shared.setAlternateIconName(target) { error in
            DispatchQueue.main.async {
                if let error {
                    print("AppIconSwitcher: не удалось сменить иконку — \(error.localizedDescription)")
                    completion(.failed)
                } else {
                    completion(.changed)
                }
            }
        }
#else
        completion(.unsupported)
#endif
    }
}
