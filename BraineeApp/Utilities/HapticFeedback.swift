//
//  HapticFeedback.swift
//  BraineeApp
//
//  Короткая вибрация при успешном действии (например, отметка задачи выполненной).

import SwiftUI

#if os(iOS)
import UIKit

enum HapticFeedback {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Отклик в момент выбора / «подхвата» карточки (ещё до движения).
    static func lift() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
#else
enum HapticFeedback {
    static func success() {}
    static func lift() {}
}
#endif
