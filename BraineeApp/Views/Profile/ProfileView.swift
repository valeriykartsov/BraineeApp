//
//  ProfileView.swift
//  BraineeApp
//
//  Профиль: пользователь, тема, дашборд, теги, хранение.

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]

    /// Активна вкладка «Профиль» — при уходе возвращаем общий вид (корень + без поиска).
    var isActive: Bool = true

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var showingEditProfile = false
    @State private var showingAccentPicker = false
    @State private var navigationResetID = UUID()
    @FocusState private var isSearchFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private var appTheme: AppTheme {
        AppTheme.resolved(from: appThemeRaw)
    }

    private var accentPalette: AccentPalette {
        AccentPalette.resolved(from: accentPaletteRaw)
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matches(_ keywords: String...) -> Bool {
        guard !query.isEmpty else { return true }
        return keywords.contains { $0.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Space.sectionGap) {
                    if isSearchExpanded {
                        GroupedSearchField(
                            text: $searchText,
                            placeholder: "Поиск настроек..."
                        )
                        .focused($isSearchFocused)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if matches("пользователь", "профиль", "имя", "аватар", "возраст", "пол") {
                        userSection
                    }

                    if matches(
                        "тема", "оформление", "светлая", "тёмная",
                        "акцент", "цвет", "оранжевый", "зелёный", "синий"
                    ) {
                        themeSection
                    }

                    if matches("дашборд", "статистика", "прогресс", "задачи") {
                        TaskDashboardView()
                    }

                    if matches(
                        "ещё", "удалённые", "удалить", "корзина", "панель", "вкладки",
                        "матрица", "привычки", "календарь", "faq", "вопрос", "вопросы", "помощь", "справка"
                    ) {
                        deletedSection
                    }

                    if matches("тег", "теги", "библиотека") {
                        TagLibraryView()
                    }

                    if matches("хранение", "данные", "json", "папка") {
                        storageSection
                    }
                }
                .groupedScreenPadding()
                .padding(.top, DesignSystem.Space.x2)
                .padding(.bottom, DesignSystem.Space.x4)
            }
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Профиль")
                        .font(DesignSystem.Typography.title(24))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    searchToggleButton
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    searchToggleButton
                }
#endif
            }
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                ensureProfile()
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    resetToOverview()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    resetToOverview()
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(
                    initialName: profile?.displayName ?? "",
                    initialAge: profile?.age,
                    initialGender: profile?.gender ?? .unspecified,
                    initialAvatarData: profile?.avatarData
                ) { name, age, gender, avatarData in
                    saveProfile(name: name, age: age, gender: gender, avatarData: avatarData)
                }
            }
            .sheet(isPresented: $showingAccentPicker) {
                AccentPalettePickerView(current: accentPalette) { selected in
                    applyAccent(selected)
                }
            }
        }
        .id(navigationResetID)
        .tint(accentPalette.color)
    }

    /// Общий вид: корень навигации, поиск закрыт, фильтр сброшен.
    private func resetToOverview() {
        searchText = ""
        isSearchExpanded = false
        isSearchFocused = false
        showingEditProfile = false
        showingAccentPicker = false
        navigationResetID = UUID()
    }

    private func applyAccent(_ selected: AccentPalette) {
        let previous = accentPalette
        accentPaletteRaw = selected.rawValue
        AppNavigationChrome.apply(accentRaw: selected.rawValue)
        modelContext.persistToJSON()

        guard selected != previous else { return }

        // Системный алерт iOS про смену иконки оставляем; своё окно не показываем.
        Task { @MainActor in
            AppIconSwitcher.apply(for: selected) { _ in }
        }
    }

    private var searchToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isSearchExpanded.toggle()
                if isSearchExpanded {
                    isSearchFocused = true
                } else {
                    searchText = ""
                    isSearchFocused = false
                }
            }
        } label: {
            Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentPalette.color)
        }
        .accessibilityLabel(isSearchExpanded ? "Закрыть поиск" : "Поиск")
    }

    private var userSection: some View {
        GroupedSection(title: "Пользователь") {
            HStack(alignment: .top, spacing: DesignSystem.Space.x3) {
                AvatarImageView(
                    avatarData: profile?.avatarData,
                    size: DesignSystem.Space.grid(18)
                )

                VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                    Text(displayNameText)
                        .font(DesignSystem.Typography.headline())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    HStack(alignment: .top, spacing: DesignSystem.Space.x3) {
                        labeledValue(title: "Возраст", value: ageText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        labeledValue(
                            title: "Пол",
                            value: profile?.gender.title ?? UserGender.unspecified.title
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)

                IconTapButton(
                    systemName: DesignSystem.Icon.pencil,
                    tint: accentPalette.color,
                    compact: true,
                    accessibilityLabel: "Редактировать профиль"
                ) {
                    showingEditProfile = true
                }
            }
            .padding(DesignSystem.Space.x3)
        }
    }

    private var displayNameText: String {
        let name = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Без имени" : name
    }

    private var ageText: String {
        guard let age = profile?.age else { return "Не указан" }
        return "\(age)"
    }

    private func labeledValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.caption(12))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text(value)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }

    private var themeSection: some View {
        GroupedSection(title: "Тема оформления") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                HStack(spacing: DesignSystem.Space.x3) {
                    Image(systemName: DesignSystem.Icon.paintbrush)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(accentPalette.color)
                        .frame(width: DesignSystem.Space.x6, height: DesignSystem.Space.x6)
                    Text("Тема")
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

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

                Button {
                    showingAccentPicker = true
                } label: {
                    HStack(spacing: DesignSystem.Space.x3) {
                        Circle()
                            .fill(accentPalette.color)
                            .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Акцентный цвет")
                                .font(DesignSystem.Typography.caption(12))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Text(accentPalette.title)
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Space.x3)
                    .padding(.vertical, DesignSystem.Space.x3)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(DesignSystem.Colors.chip)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выбрать акцентный цвет")
            }
            .padding(DesignSystem.Space.x3)
        }
    }

    private var deletedSection: some View {
        GroupedSection(title: "Ещё") {
            NavigationLink {
                TabBarSettingsView()
            } label: {
                GroupedNavRow(title: "Панель вкладок", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                FAQView()
            } label: {
                GroupedNavRow(title: "FAQ", systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                DeletedTasksFolderView()
            } label: {
                GroupedNavRow(title: "Удалённые задачи", systemImage: DesignSystem.Icon.trash)
            }
            .buttonStyle(.plain)
        }
    }

    private var storageSection: some View {
        GroupedSection(title: "Хранение данных") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                HStack(spacing: DesignSystem.Space.x2) {
                    Image(systemName: DesignSystem.Icon.storage)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(accentPalette.color)
                        .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    Text("Папка")
                        .font(DesignSystem.Typography.body(16))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text(AppDataStore.folderName)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Text("Данные хранятся локально в Documents/BraineeApp (mytasks.json, profile.json). Резервная копия — в Keychain.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Space.x3)
        }
    }

    private func ensureProfile() {
        guard profiles.isEmpty else { return }
        let newProfile = UserProfile(displayName: "")
        modelContext.insert(newProfile)
        modelContext.persistToJSON()
    }

    private func saveProfile(name: String, age: Int?, gender: UserGender, avatarData: Data?) {
        ensureProfile()
        guard let profile else { return }
        profile.displayName = name
        profile.age = age
        profile.gender = gender
        profile.avatarData = avatarData
        modelContext.persistToJSON()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self, TaskTag.self], inMemory: true)
}
