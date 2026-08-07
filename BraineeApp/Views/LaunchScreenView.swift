//
//  LaunchScreenView.swift
//  BraineeApp
//
//  Загрузочный экран: анимированный логотип + название + слоган.

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    var playsLogoAnimation: Bool = true

    private var splashBackground: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ZStack {
            splashBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                AppLogoMark(
                    size: DesignSystem.Space.grid(32),
                    playsAppearAnimation: playsLogoAnimation
                )

                Text("BraineeApp")
                    .font(DesignSystem.Typography.title(28))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Space.x5)

                Text("Make your day!")
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Space.x2)
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
