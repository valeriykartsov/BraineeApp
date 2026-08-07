//
//  PankinNavigationChrome.swift
//  BraineeApp
//
//  Единый вид navigation bar: моноширинный заголовок, фон как у разделов.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PankinNavigationChrome {
    /// Применяет стиль панели навигации под дизайн-систему.
    @MainActor
    static func apply() {
#if canImport(UIKit)
        let background = UIColor(DesignSystem.Colors.background)
        let titleColor = UIColor(DesignSystem.Colors.textPrimary)
        let titleFont = UIFont.monospacedSystemFont(ofSize: 17, weight: .bold)
        let largeFont = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = UIColor(DesignSystem.Colors.divider)
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: titleColor
        ]
        appearance.largeTitleTextAttributes = [
            .font: largeFont,
            .foregroundColor: titleColor
        ]

        let nav = UINavigationBar.appearance()
        nav.standardAppearance = appearance
        nav.compactAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.tintColor = UIColor(DesignSystem.Colors.accent)
#endif
    }
}

/// Модификатор экрана раздела: крупный моно-заголовок слева и фон.
struct PankinSectionChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
    }
}

extension View {
    func pankinSectionChrome() -> some View {
        modifier(PankinSectionChrome())
    }
}
