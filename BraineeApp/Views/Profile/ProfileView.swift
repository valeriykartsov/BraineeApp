//
//  ProfileView.swift
//  BraineeApp
//
//  Экран профиля: имя, аватар, тема, дашборд, удалённые задачи и библиотека тегов.

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var displayName = ""

    private var profile: UserProfile? { profiles.first }

    private var appTheme: AppTheme {
        AppTheme.resolved(from: appThemeRaw)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                AvatarImageView(avatarData: profile?.avatarData)
                            }
                            .buttonStyle(.plain)

                            TextField("Ваше имя", text: $displayName)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .onChange(of: displayName) { _, newValue in
                                    profile?.displayName = newValue
                                    modelContext.persistToJSON()
                                }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Тема оформления") {
                    Picker("Тема", selection: Binding(
                        get: { appTheme },
                        set: {
                            appThemeRaw = $0.rawValue
                            modelContext.persistToJSON()
                        }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                TaskDashboardView()

                Section {
                    NavigationLink {
                        DeletedTasksFolderView()
                    } label: {
                        Label("Удалённые задачи", systemImage: "trash")
                    }
                }

                TagLibraryView()

                Section {
                    LabeledContent("Папка", value: AppDataStore.folderName)
                    Text("Данные хранятся локально в Documents/BraineeApp (mytasks.json, profile.json). Резервная копия сохраняется в Keychain и восстанавливается после переустановки приложения.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Хранение данных")
                }
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

    /// Создаёт профиль в базе, если пользователь открыл приложение впервые.
    private func ensureProfile() {
        guard profiles.isEmpty else { return }
        let newProfile = UserProfile(displayName: "")
        modelContext.insert(newProfile)
        modelContext.persistToJSON()
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }

        await MainActor.run {
            ensureProfile()
            profile?.avatarData = data
            modelContext.persistToJSON()
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self, TaskTag.self], inMemory: true)
}
