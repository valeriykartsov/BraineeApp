//
//  ProfileView.swift
//  BraineeApp
//
//  Профиль: пользователь, дашборд, дополнительно (матрица, FAQ, удалённые),
//  настройки (оформление, уведомления, календарь, LLM, вкладки), теги, хранение, автор и проект на GitHub.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]

    /// Активна вкладка «Профиль» — при уходе возвращаем общий вид (корень + без поиска).
    var isActive: Bool = true

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var showingEditProfile = false
    @State private var showingMatrix = false
    @State private var navigationResetID = UUID()
    @State private var backupFile: BackupFile?
    @State private var backupFileName = ""
    @State private var isExportingBackup = false
    @State private var backupMessage: String?
    @State private var pendingBackupSummary = ""
    @State private var isImportingBackup = false
    @State private var pendingRestore: BackupRestore.Preview?
    @FocusState private var isSearchFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private var accentPalette: AccentPalette {
        AccentPalette.resolved(from: accentPaletteRaw)
    }

    private func matches(_ keywords: String...) -> Bool {
        SettingsSearch.matches(query: searchText, keywords: keywords)
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

                    if matches("дашборд", "статистика", "прогресс", "задачи") {
                        TaskDashboardView()
                    }

                    if matches(
                        "дополнительно", "матрица", "эйзенхауэр",
                        "faq", "вопрос", "вопросы", "помощь", "справка",
                        "удалённые", "удалить", "корзина"
                    ) {
                        extraSection
                    }

                    if matches(
                        "настройки", "панель", "вкладки", "привычки", "календарь",
                        "тема", "оформление", "светлая", "тёмная", "акцент", "цвет",
                        "ориентация", "положение", "вертикал", "горизонтал",
                        "уведомлен", "напомина", "дедлайн", "пуш", "пуши",
                        "llm", "openrouter", "ключ", "модель", "ассистент"
                    ) {
                        settingsSection
                    }

                    if matches("тег", "теги", "библиотека") {
                        TagLibraryView()
                    }

                    if matches("хранение", "данные", "json", "папка", "бэкап", "резерв", "копия", "экспорт", "восстан", "импорт") {
                        storageSection
                    }

                    if matches("github", "гитхаб", "автор", "проект", "исходный код") {
                        aboutFooter
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
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupFile,
                contentType: .json,
                defaultFilename: backupFileName
            ) { result in
                finishBackupExport(result)
            }
            .alert(
                "Резервная копия",
                isPresented: Binding(
                    get: { backupMessage != nil },
                    set: { if !$0 { backupMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
            .alert(
                "Восстановить из резервной копии?",
                isPresented: Binding(
                    get: { pendingRestore != nil },
                    set: { if !$0 { pendingRestore = nil } }
                ),
                presenting: pendingRestore
            ) { preview in
                Button("Заменить данные", role: .destructive) {
                    performRestore(preview)
                }
                Button("Отмена", role: .cancel) {}
            } message: { preview in
                Text(
                    "Копия от \(preview.exportedAt.formatted(date: .abbreviated, time: .shortened)).\n"
                        + "\(preview.summary)\n\n"
                        + "Текущие задачи, папки, теги, привычки и профиль будут заменены. "
                        + "Перед заменой они сохранятся в Backups/pre-restore. Аватар останется текущим."
                )
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
        showingMatrix = false
        navigationResetID = UUID()
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

    /// Под дашбордом: дополнительные представления задач (NAV-1).
    private var extraSection: some View {
        GroupedSection(title: "Дополнительно") {
            // Листом, а не переходом: у Матрицы своя навигация к квадрантам.
            Button {
                showingMatrix = true
            } label: {
                GroupedNavRow(title: "Матрица Эйзенхауэра", systemImage: "square.grid.2x2")
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
        .sheet(isPresented: $showingMatrix) {
            EisenhowerMatrixView()
        }
    }

    private var settingsSection: some View {
        GroupedSection(title: "Настройки") {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                GroupedNavRow(title: "Тема оформления", systemImage: DesignSystem.Icon.paintbrush)
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                NotificationSettingsView()
            } label: {
                GroupedNavRow(title: "Уведомления", systemImage: "bell")
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                CalendarExportSettingsView()
            } label: {
                GroupedNavRow(title: "Календарь", systemImage: "calendar")
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                LLMSettingsView()
            } label: {
                GroupedNavRow(title: "LLM", systemImage: "sparkles")
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            NavigationLink {
                TabBarSettingsView()
            } label: {
                GroupedNavRow(title: "Панель вкладок", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain)
        }
    }

    private static let authorGitHubURL = URL(string: "https://github.com/valeriykartsov")!
    private static let projectGitHubURL = URL(string: "https://github.com/valeriykartsov/BraineeApp")!

    /// Самый низ Профиля: автор и проект на GitHub.
    private var aboutFooter: some View {
        VStack(spacing: DesignSystem.Space.x1) {
            Link(destination: Self.authorGitHubURL) {
                Label("@valeriykartsov", systemImage: DesignSystem.Icon.person)
            }
            Link(destination: Self.projectGitHubURL) {
                Label("github.com/valeriykartsov/BraineeApp", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
        .font(DesignSystem.Typography.caption())
        .foregroundStyle(accentPalette.color)
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.Space.x2)
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
                    Text(ModelContainerFactory.folderName)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Text("Данные хранятся локально в хранилище приложения. Автобэкап — раз в сутки при сворачивании, последние 7 копий.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Space.x3)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            Button {
                prepareBackupExport()
            } label: {
                GroupedNavRow(
                    title: "Экспорт резервной копии",
                    systemImage: "square.and.arrow.up",
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)

            InsetDivider(leading: DesignSystem.Space.rowIconInset)

            Button {
                isImportingBackup = true
            } label: {
                GroupedNavRow(
                    title: "Восстановить из резервной копии",
                    systemImage: "square.and.arrow.down",
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            // Отдельно от fileExporter на NavigationStack: два файловых диалога на одном View конфликтуют.
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                prepareRestore(result)
            }
        }
    }

    /// Собирает бэкап из текущих данных и открывает системный диалог сохранения (Файлы / iCloud Drive).
    private func prepareBackupExport() {
        try? modelContext.save()
        let now = Date.now
        let document = BackupDocument.make(from: modelContext, now: now)
        do {
            backupFile = BackupFile(data: try document.encoded())
            backupFileName = BackupDocument.defaultFileName(for: now)
            pendingBackupSummary = document.summary
            isExportingBackup = true
        } catch {
            print("Backup export failed: \(error)")
            backupMessage = "Не удалось подготовить файл: \(error.localizedDescription)"
        }
    }

    private func finishBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            backupMessage = "Сохранено: \(url.lastPathComponent)\n\(pendingBackupSummary)"
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                print("Backup export failed: \(error)")
                backupMessage = "Не удалось сохранить файл: \(error.localizedDescription)"
            }
        }
        backupFile = nil
    }

    /// Читает выбранный файл и показывает предпросмотр. Невалидный файл — сообщение, данные не трогаются.
    private func prepareRestore(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                pendingRestore = try BackupRestore.preview(Data(contentsOf: url))
            } catch {
                backupMessage = "Файл не подходит для восстановления: \(error.localizedDescription)"
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                backupMessage = "Не удалось открыть файл: \(error.localizedDescription)"
            }
        }
    }

    private func performRestore(_ preview: BackupRestore.Preview) {
        try? modelContext.save()
        do {
            let safetyURL = try BackupRestore().restore(preview, into: modelContext.container)
            modelContext.didChange()
            AppIconSwitcher.syncWithCurrentAccent()
            backupMessage = "Данные восстановлены.\n\(preview.summary)\n"
                + "Прежние данные сохранены: \(safetyURL.lastPathComponent)"
        } catch {
            backupMessage = "Не удалось восстановить данные: \(error.localizedDescription)"
        }
        pendingRestore = nil
    }

    private var profileService: ProfileService {
        ProfileService(context: modelContext)
    }

    private func ensureProfile() {
        profileService.ensureProfile()
    }

    private func saveProfile(name: String, age: Int?, gender: UserGender, avatarData: Data?) {
        profileService.update(name: name, age: age, gender: gender, avatarData: avatarData)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self, TaskTag.self], inMemory: true)
}
