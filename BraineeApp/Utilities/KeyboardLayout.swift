//
//  KeyboardLayout.swift
//  BraineeApp
//
//  Панель вкладок не поднимается над клавиатурой (п. 57): корневой экран игнорирует клавиатуру.
//  Панель — плавающая капсула поверх содержимого (п. 60); содержимое вкладок резервирует снизу место
//  под капсулу, а при клавиатуре — до её верха. «Призрачная» клавиатура (полоса над клавиатурой
//  без самой клавиатуры) ниже капсулы ничего не сдвигает.

import SwiftUI
import UIKit

enum KeyboardLayout {
    /// Верх клавиатуры в координатах экрана; `nil` — клавиатуры на экране нет (скрыта или аппаратная).
    static func keyboardTop(frameEnd: CGRect, screenHeight: CGFloat) -> CGFloat? {
        guard !frameEnd.isEmpty, frameEnd.minY < screenHeight else { return nil }
        return frameEnd.minY
    }

    /// Нижний отступ содержимого вкладок над безопасной зоной: место под капсулу панели
    /// или, если клавиатура выше, — до верха клавиатуры. `contentBottom` — низ корня (над индикатором «домой»).
    static func contentBottomInset(tabBarReserve: CGFloat, contentBottom: CGFloat, keyboardTop: CGFloat?) -> CGFloat {
        guard let keyboardTop else { return tabBarReserve }
        return max(tabBarReserve, contentBottom - keyboardTop)
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
