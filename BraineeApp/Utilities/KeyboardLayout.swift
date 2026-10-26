//
//  KeyboardLayout.swift
//  BraineeApp
//
//  Панель вкладок не поднимается над клавиатурой (п. 57): корневой экран игнорирует клавиатуру,
//  а содержимое вкладок получает нижний отступ только на ту часть клавиатуры, что выше панели.
//  Так «призрачная» клавиатура (полоса над клавиатурой без самой клавиатуры) панель не сдвигает.

import SwiftUI
import UIKit

enum KeyboardLayout {
    /// Верх клавиатуры в координатах экрана; `nil` — клавиатуры на экране нет (скрыта или аппаратная).
    static func keyboardTop(frameEnd: CGRect, screenHeight: CGFloat) -> CGFloat? {
        guard !frameEnd.isEmpty, frameEnd.minY < screenHeight else { return nil }
        return frameEnd.minY
    }

    /// Отступ снизу у содержимого вкладок: насколько клавиатура заходит выше верхнего края панели.
    static func contentBottomPadding(tabBarTop: CGFloat, keyboardTop: CGFloat?) -> CGFloat {
        guard let keyboardTop else { return 0 }
        return max(0, tabBarTop - keyboardTop)
    }

    /// Снимает фокус ввода во всём приложении — клавиатура закрывается, даже если поле уже не видно.
    @MainActor
    static func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Положение клавиатуры по системным уведомлениям.
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published private(set) var keyboardTop: CGFloat?

    private var tokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            MainActor.assumeIsolated { self?.update(frameEnd: frame) }
        })
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.update(frameEnd: .zero) }
        })
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func update(frameEnd: CGRect) {
        let screenHeight = UIScreen.main.bounds.height
        let top = KeyboardLayout.keyboardTop(frameEnd: frameEnd, screenHeight: screenHeight)
        guard top != keyboardTop else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardTop = top
        }
    }
}
