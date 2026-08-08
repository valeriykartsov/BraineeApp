//
//  AppearanceSettingsView.swift
//  BraineeApp
//
//  Оформление: тема, акцентный цвет и фиксация вертикальной ориентации.

import SwiftUI
import SwiftData

struct AppearanceSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue
    @AppStorage(OrientationLockSettings.lockPortraitKey)
    private var lockPortrait = OrientationLockSettings.defaultLocked

    @State private var showingAccentPicker = false

    private var appTheme: AppTheme {
        AppTheme.resolved(from: appThemeRaw)
    }

    private var accentPalette: AccentPalette {
        AccentPalette.resolved(from: accentPaletteRaw)
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
                                modelContext.persistToJSON()
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

    private func applyAccent(_ selected: AccentPalette) {
        let previous = accentPalette
        accentPaletteRaw = selected.rawValue
        AppNavigationChrome.apply(accentRaw: selected.rawValue)
        modelContext.persistToJSON()

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
