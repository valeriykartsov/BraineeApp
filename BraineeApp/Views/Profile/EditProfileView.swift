//
//  EditProfileView.swift
//  BraineeApp
//
//  Редактирование профиля: имя, возраст, пол, фото. Сохранение с подтверждением.

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    let initialAge: Int?
    let initialGender: UserGender
    let initialAvatarData: Data?

    var onSave: (_ name: String, _ age: Int?, _ gender: UserGender, _ avatarData: Data?) -> Void

    @State private var displayName: String
    @State private var ageText: String
    @State private var gender: UserGender
    @State private var avatarData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingSaveConfirm = false

    init(
        initialName: String,
        initialAge: Int?,
        initialGender: UserGender,
        initialAvatarData: Data?,
        onSave: @escaping (_ name: String, _ age: Int?, _ gender: UserGender, _ avatarData: Data?) -> Void
    ) {
        self.initialName = initialName
        self.initialAge = initialAge
        self.initialGender = initialGender
        self.initialAvatarData = initialAvatarData
        self.onSave = onSave
        _displayName = State(initialValue: initialName)
        _ageText = State(initialValue: initialAge.map(String.init) ?? "")
        _gender = State(initialValue: initialGender)
        _avatarData = State(initialValue: initialAvatarData)
    }

    private var parsedAge: Int? {
        let trimmed = ageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), (1...120).contains(value) else {
            return nil
        }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            AvatarImageView(avatarData: avatarData, size: DesignSystem.Space.grid(22))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    Text("Нажмите на фото, чтобы изменить")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Имя", text: $displayName)
                        .font(DesignSystem.Typography.body())
                    TextField("Возраст", text: $ageText)
                        .font(DesignSystem.Typography.body())
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                    Picker("Пол", selection: $gender) {
                        ForEach(UserGender.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                } header: {
                    Text("Данные")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .tint(DesignSystem.Colors.accent)
            .navigationTitle("Редактировать")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        showingSaveConfirm = true
                    }
                }
            }
            .alert("Сохранить изменения?", isPresented: $showingSaveConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") {
                    commitSave()
                }
            } message: {
                Text("Новые данные профиля будут записаны в profile.json и Keychain.")
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
        }
    }

    private func commitSave() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(name, parsedAge, gender, avatarData)
        dismiss()
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run {
            avatarData = data
        }
    }
}
