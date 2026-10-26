//
//  AppearanceSettingsView.swift
//  BraineeApp
//
//  Оформление: тема, акцентный цвет, фон (картинка, D-48) и фиксация вертикальной ориентации.

import SwiftUI
import SwiftData
import PhotosUI

struct AppearanceSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @AppStorage(OrientationLockSettings.lockPortraitKey)
    private var lockPortrait = OrientationLockSettings.defaultLocked

    @State private var showingAccentPicker = false

    @AppStorage(AppBackgroundSettings.modeKey) private var backgroundModeRaw = AppBackgroundMode.none.rawValue
    @AppStorage(AppBackgroundSettings.blurKey) private var backgroundBlur = false
    @ObservedObject private var backgroundStore = AppBackgroundStore.shared
    /// Ползунок меняет значение на экране, а в UserDefaults (и журнал) пишет только по отпусканию.
    @State private var backgroundDim = AppBackgroundSettings.dim()
    @State private var selectedBackgroundPhoto: PhotosPickerItem?
    @State private var isLoadingBackground = false
    @State private var backgroundError: String?
    @State private var showingDeleteBackground = false

    private var appTheme: AppTheme {
        AppTheme.resolved(from: appThemeRaw)
    }

    private var accentPalette: AccentPalette {
        AccentPalette.resolved(from: accentPaletteRaw)
    }

    private var backgroundMode: AppBackgroundMode {
        AppBackgroundMode.resolved(from: backgroundModeRaw)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Space.sectionGap) {
                GroupedSection(title: "Тема") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        Picker("Тема", selection: Binding(
                            get: { appTheme },
                            set: {
                                appThemeRaw = $0.rawValue
                                ProfileService(context: modelContext).appearanceDidChange()
                            }
                        )) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.title).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Системная следует настройкам устройства. Светлая и тёмная фиксируют оформление приложения.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Space.x3)
                }

                GroupedSection(title: "Акцент") {
                    Button {
                        showingAccentPicker = true
                    } label: {
                        HStack(spacing: DesignSystem.Space.x3) {
                            Circle()
                                .fill(accentPalette.color)
                                .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Акцентный цвет")
                                    .font(DesignSystem.Typography.body(16))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(accentPalette.title)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }

                            Spacer(minLength: DesignSystem.Space.x2)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.7))
                        }
                        .padding(.horizontal, DesignSystem.Space.x3)
                        .padding(.vertical, DesignSystem.Space.x2 + 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Выбрать акцентный цвет")
                }

                backgroundSection

                GroupedSection(title: "Ориентация") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        Toggle(isOn: $lockPortrait) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Зафиксировать положение")
                                    .font(DesignSystem.Typography.body(16))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("Только вертикальная ориентация")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .tint(DesignSystem.Colors.accent)
                        .onChange(of: lockPortrait) { _, locked in
#if canImport(UIKit)
                            OrientationLockSettings.apply(lockPortrait: locked)
#endif
                        }

                        Text("При включении экран остаётся вертикальным — приоритет над системной настройкой поворота. Выключите, чтобы разрешить горизонтальную ориентацию.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Space.x3)
                }
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("Тема оформления")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
        .dismissOnTabLeave($showingAccentPicker)
        .onChange(of: selectedBackgroundPhoto) { _, item in
            guard let item else { return }
            loadBackground(from: item)
        }
        .alert("Удалить картинку фона?", isPresented: $showingDeleteBackground) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { deleteBackground() }
        } message: {
            Text("Фон станет однотонным. Картинка в галерее останется.")
        }
        .sheet(isPresented: $showingAccentPicker) {
            AccentPalettePickerView(current: accentPalette) { selected in
                applyAccent(selected)
            }
        }
        .onAppear {
#if canImport(UIKit)
            OrientationLockSettings.apply(lockPortrait: lockPortrait)
#endif
        }
    }

    // MARK: - Фон

    private var backgroundSection: some View {
        GroupedSection(title: "Фон") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                Picker("Фон", selection: Binding(
                    get: { backgroundMode },
                    set: { setBackgroundMode($0) }
                )) {
                    ForEach(AppBackgroundMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: DesignSystem.Space.x3) {
                    backgroundPreview

                    VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                        PhotosPicker(selection: $selectedBackgroundPhoto, matching: .images) {
                            Text(backgroundStore.hasImage ? "Заменить картинку" : "Выбрать картинку")
                                .font(DesignSystem.Typography.body(16))
                        }
                        .disabled(isLoadingBackground)

                        if backgroundStore.hasImage {
                            Button("Удалить картинку", role: .destructive) {
                                showingDeleteBackground = true
                            }
                            .font(DesignSystem.Typography.body(16))
                        }
                    }
                    Spacer(minLength: 0)
                }

                if let backgroundError {
                    Text(backgroundError)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.danger)
                }

                if backgroundMode == .image && backgroundStore.hasImage {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                        HStack {
                            Text("Затемнение")
                                .font(DesignSystem.Typography.body(16))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text(AppBackgroundSettings.percentText(backgroundDim))
                                .font(DesignSystem.Typography.body(16))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(value: $backgroundDim, in: 0...AppBackgroundSettings.maxDim, step: 0.05) { editing in
                            if !editing { saveBackgroundDim() }
                        }
                        .accessibilityLabel("Затемнение фона")
                    }

                    Toggle(isOn: $backgroundBlur) {
                        Text("Размытие")
                            .font(DesignSystem.Typography.body(16))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    .tint(DesignSystem.Colors.accent)
                }

                Text("Картинка лежит под всеми экранами, кроме форм. Светлая и тёмная тема меняют элементы поверх неё. Картинка хранится только на этом iPhone и не входит в резервную копию.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Space.x3)
        }
    }

    private var backgroundPreview: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
            .fill(DesignSystem.Colors.chip)
            .overlay {
                if isLoadingBackground {
                    ProgressView()
                } else if let image = backgroundStore.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .frame(width: 56, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous))
            .accessibilityHidden(true)
    }

    private func setBackgroundMode(_ mode: AppBackgroundMode) {
        backgroundModeRaw = mode.rawValue
        AppNavigationChrome.apply(accentRaw: accentPaletteRaw)
    }

    private func saveBackgroundDim() {
        backgroundDim = AppBackgroundSettings.clampedDim(backgroundDim)
        UserDefaults.standard.set(backgroundDim, forKey: AppBackgroundSettings.dimKey)
    }

    private func loadBackground(from item: PhotosPickerItem) {
        isLoadingBackground = true
        backgroundError = nil
        Task { @MainActor in
            defer {
                isLoadingBackground = false
                selectedBackgroundPhoto = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw BackgroundImageError.unreadable
                }
                let hadImage = backgroundStore.hasImage
                try backgroundStore.setImage(data: data)
                SessionLog.shared.add(
                    .settings, "Настройка изменена",
                    subject: "Картинка фона",
                    changes: [hadImage ? "Заменена" : "Выбрана"]
                )
                setBackgroundMode(.image)
            } catch {
                backgroundError = BackgroundImageError.unreadable.errorDescription
            }
        }
    }

    private func deleteBackground() {
        do {
            try backgroundStore.removeImage()
            SessionLog.shared.add(.settings, "Настройка изменена", subject: "Картинка фона", changes: ["Удалена"])
            setBackgroundMode(.none)
        } catch {
            backgroundError = "Не удалось удалить картинку."
        }
    }

    private func applyAccent(_ selected: AccentPalette) {
        let previous = accentPalette
        accentPaletteRaw = selected.rawValue
        AppNavigationChrome.apply(accentRaw: selected.rawValue)
        ProfileService(context: modelContext).appearanceDidChange()

        guard selected != previous else { return }

        Task { @MainActor in
            AppIconSwitcher.apply(for: selected) { _ in }
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
