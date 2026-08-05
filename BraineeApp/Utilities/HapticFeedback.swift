//
//  HapticFeedback.swift
//  BraineeApp
//

import SwiftUI

#if os(iOS)
import UIKit

enum HapticFeedback {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
#else
enum HapticFeedback {
    static func success() {}
}
#endif
