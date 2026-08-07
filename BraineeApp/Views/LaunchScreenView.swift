//
//  LaunchScreenView.swift
//  BraineeApp
//
//  Адаптивный загрузочный экран: фон как у разделов, логотип и текст под тему.

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Тот же фон, что у Карьера / Спорт / Ментальное / Профиль.
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Space.x5) {
                PankinLogoMark(size: DesignSystem.Space.grid(36))

                Text("BraineeApp")
                    .font(DesignSystem.Typography.title(28))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Make your day!")
                    .font(DesignSystem.Typography.data(14))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("BraineeApp. Make your day!")
        }
    }
}

#Preview("Light") {
    LaunchScreenView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LaunchScreenView()
        .preferredColorScheme(.dark)
}
