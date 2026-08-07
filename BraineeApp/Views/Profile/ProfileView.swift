//
//  ProfileView.swift
//  BraineeApp
//
//  Профиль в палитре и типографике дизайн-системы.

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
                        VStack(spacing: DesignSystem.Space.x4) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                AvatarImageView(avatarData: profile?.avatarData)
                            }
                            .buttonStyle(.plain)

                            TextField("Ваше имя", text: $displayName)
                                .font(DesignSystem.Typography.title(18))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
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

                Section {
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
                    .listRowBackground(DesignSystem.Colors.surface)
                } header: {
                    Text("Тема оформления")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }

                TaskDashboardView()

                Section {
                    NavigationLink {
                        DeletedTasksFolderView()
                    } label: {
                        Label("Удалённые задачи", systemImage: DesignSystem.Icon.trash)
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    .listRowBackground(DesignSystem.Colors.surface)
                }

                TagLibraryView()

                Section {
                    LabeledContent("Папка", value: AppDataStore.folderName)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Данные хранятся локально в Documents/BraineeApp (mytasks.json, profile.json). Резервная копия сохраняется в Keychain и восстанавливается после переустановки приложения.")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } header: {
                    Text("Хранение данных")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .tint(DesignSystem.Colors.accent)
            .navigationTitle("Профиль")
            .pankinSectionChrome()
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
