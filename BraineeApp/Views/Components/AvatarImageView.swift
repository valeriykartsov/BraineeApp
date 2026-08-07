//
//  AvatarImageView.swift
//  BraineeApp
//
//  Аватар: квадрат со скруглением 4pt (геометрия Панкина), фото или заглушка.

import SwiftUI

struct AvatarImageView: View {
    let avatarData: Data?
    var size: CGFloat = DesignSystem.Space.grid(25) // 100

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .circular)
    }

    var body: some View {
        if let avatarData, let platformImage = PlatformImage.make(from: avatarData) {
            platformImage
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(DesignSystem.Colors.divider, lineWidth: DesignSystem.Stroke.hairline)
                }
        } else {
            ZStack {
                shape
                    .fill(DesignSystem.Colors.surface)
                    .frame(width: size, height: size)
                    .overlay {
                        shape.strokeBorder(DesignSystem.Colors.divider, lineWidth: DesignSystem.Stroke.hairline)
                    }

                Image(systemName: DesignSystem.Icon.person)
                    .font(.system(size: size * 0.36, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    AvatarImageView(avatarData: nil)
}
