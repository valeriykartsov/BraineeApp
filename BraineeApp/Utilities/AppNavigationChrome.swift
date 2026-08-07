//
//  AppNavigationChrome.swift
//  BraineeApp
//
//  Единый стиль navigation bar: чуть компактнее large title, выше к статус-бару.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppNavigationChrome {
    /// Размер large title для разделов и профиля.
    static let largeTitleSize: CGFloat = 28

    @MainActor
    static func apply() {
#if canImport(UIKit)
        let background = UIColor(DesignSystem.Colors.background)
        let titleColor = UIColor(DesignSystem.Colors.textPrimary)
        let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let largeFont = UIFont.systemFont(ofSize: largeTitleSize, weight: .bold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: titleColor
        ]
        appearance.largeTitleTextAttributes = [
            .font: largeFont,
            .foregroundColor: titleColor
        ]

        let accent = UIColor(DesignSystem.Colors.accent)

        let nav = UINavigationBar.appearance()
        nav.standardAppearance = appearance
        nav.compactAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.tintColor = accent
        // Чуть поднимаем inline-заголовок; large title становится компактнее за счёт меньшего шрифта.
        nav.setTitleVerticalPositionAdjustment(-2, for: .default)
        nav.setTitleVerticalPositionAdjustment(-2, for: .compact)

        // Кнопки системных алертов (UIAlertController) берут tint отсюда, не из SwiftUI.
        UIView.appearance().tintColor = accent
#endif
    }
}

struct AppSectionChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
    }
}

extension View {
    func appSectionChrome() -> some View {
        modifier(AppSectionChrome())
    }
}
