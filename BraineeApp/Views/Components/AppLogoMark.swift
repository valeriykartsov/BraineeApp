//
//  AppLogoMark.swift
//  BraineeApp
//
//  Знак из трёх полос — пропорции как у AppIcon (~50% / ~68% / ~50%).
//  Опционально: анимация появления (верх/низ справа, середина слева).

import SwiftUI

struct AppLogoMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat
    var playsAppearAnimation: Bool

    @State private var outerOffsetX: CGFloat
    @State private var middleOffsetX: CGFloat
    @State private var didRunAnimation = false

    init(size: CGFloat = DesignSystem.Space.grid(36), playsAppearAnimation: Bool = false) {
        self.size = size
        self.playsAppearAnimation = playsAppearAnimation
        let start = size * 1.25
        _outerOffsetX = State(initialValue: playsAppearAnimation ? start : 0)
        _middleOffsetX = State(initialValue: playsAppearAnimation ? -start : 0)
    }

    private var outerBarColor: Color {
        colorScheme == .dark ? .white : .black
    }

    /// Замерено по AppIcon.png: белые ~0.50 ширины, оранжевая ~0.68.
    private var outerBarWidth: CGFloat { size * 0.50 }
    private var middleBarWidth: CGFloat { size * 0.68 }
    private var barHeight: CGFloat { size * 0.064 }
    private var gap: CGFloat { size * 0.092 }

    var body: some View {
        VStack(spacing: gap) {
            bar(color: outerBarColor, width: outerBarWidth, height: barHeight)
                .offset(x: outerOffsetX)
            bar(color: DesignSystem.Colors.accent, width: middleBarWidth, height: barHeight)
                .offset(x: middleOffsetX)
            bar(color: outerBarColor, width: outerBarWidth, height: barHeight)
                .offset(x: outerOffsetX)
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
        .onAppear {
            guard playsAppearAnimation, !didRunAnimation else { return }
            didRunAnimation = true
            withAnimation(.spring(response: 0.85, dampingFraction: 0.88).delay(0.08)) {
                outerOffsetX = 0
            }
            withAnimation(.spring(response: 0.85, dampingFraction: 0.88).delay(0.22)) {
                middleOffsetX = 0
            }
        }
    }

    private func bar(color: Color, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
    }
}

#Preview("Light") {
    AppLogoMark(playsAppearAnimation: true)
        .padding()
        .background(Color.white)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AppLogoMark(playsAppearAnimation: true)
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
