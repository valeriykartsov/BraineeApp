//
//  AvatarImageView.swift
//  BraineeApp
//
//  Аватар: круг / мягкое скругление без жёсткой рамки.

import SwiftUI

struct AvatarImageView: View {
    let avatarData: Data?
    var size: CGFloat = DesignSystem.Space.grid(22) // 88

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
    }

    var body: some View {
        if let avatarData, let platformImage = PlatformImage.make(from: avatarData) {
            platformImage
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(shape)
        } else {
            ZStack {
                shape
                    .fill(DesignSystem.Colors.chip)
                    .frame(width: size, height: size)

                Image(systemName: DesignSystem.Icon.person)
                    .font(.system(size: size * 0.36, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }
}

#Preview {
    AvatarImageView(avatarData: nil)
        .padding()
        .appScreenBackground()
}
