//
//  AvatarImageView.swift
//  BraineeApp
//
//  Аватар: круг / мягкое скругление без жёсткой рамки.

import SwiftUI

struct AvatarImageView: View {
    let avatarData: Data?
    var size: CGFloat = DesignSystem.Space.grid(22) // 88

    /// Кэш декодированного изображения — иначе JPEG/PNG парсятся на каждый body.
    @State private var cachedImage: Image?
    @State private var cachedDataIdentity: Int?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
    }

    var body: some View {
        Group {
            if let cachedImage {
                cachedImage
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
        .onAppear { refreshCacheIfNeeded() }
        .onChange(of: avatarData) { _, _ in
            refreshCacheIfNeeded(force: true)
        }
    }

    private func refreshCacheIfNeeded(force: Bool = false) {
        guard let avatarData else {
            cachedImage = nil
            cachedDataIdentity = nil
            return
        }
        let identity = avatarData.hashValue
        guard force || cachedDataIdentity != identity else { return }
        cachedImage = PlatformImage.make(from: avatarData)
        cachedDataIdentity = identity
    }
}

#Preview {
    AvatarImageView(avatarData: nil)
        .padding()
        .appScreenBackground()
}
