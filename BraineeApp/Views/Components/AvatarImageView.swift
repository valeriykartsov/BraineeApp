//
//  AvatarImageView.swift
//  BraineeApp
//
//  Круглый аватар пользователя: фото из данных профиля или заглушка.

import SwiftUI

struct AvatarImageView: View {
    let avatarData: Data?
    var size: CGFloat = 100

    var body: some View {
        if let avatarData, let platformImage = PlatformImage.make(from: avatarData) {
            platformImage
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                }
        } else {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: size, height: size)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AvatarImageView(avatarData: nil)
}
