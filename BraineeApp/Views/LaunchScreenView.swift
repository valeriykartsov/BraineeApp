//
//  LaunchScreenView.swift
//  BraineeApp
//
//  Стартовый экран с логотипом, показывается на 1–2 секунды при запуске.

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

                Text("BraineeApp")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Make your day!")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
