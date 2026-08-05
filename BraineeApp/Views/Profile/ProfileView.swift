//
//  ProfileView.swift
//  BraineeApp
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var displayName = ""

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatarView
                }
                .buttonStyle(.plain)

                TextField("Ваше имя", text: $displayName)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .onChange(of: displayName) { _, newValue in
                        profile?.displayName = newValue
                    }

                Spacer()
                Spacer()
            }
            .navigationTitle("Профиль")
            .onAppear {
                ensureProfile()
                displayName = profile?.displayName ?? ""
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = profile?.avatarData, let uiImage = platformImage(from: data) {
            platformImageView(uiImage)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                }
        } else {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 120, height: 120)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ensureProfile() {
        guard profiles.isEmpty else { return }
        let newProfile = UserProfile(displayName: "")
        modelContext.insert(newProfile)
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }

        await MainActor.run {
            ensureProfile()
            profile?.avatarData = data
        }
    }
}

#if os(iOS)
import UIKit

private func platformImage(from data: Data) -> UIImage? {
    UIImage(data: data)
}

private func platformImageView(_ image: UIImage) -> some View {
    Image(uiImage: image)
        .resizable()
        .scaledToFill()
}
#else
import AppKit

private func platformImage(from data: Data) -> NSImage? {
    NSImage(data: data)
}

private func platformImageView(_ image: NSImage) -> some View {
    Image(nsImage: image)
        .resizable()
        .scaledToFill()
}
#endif

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
