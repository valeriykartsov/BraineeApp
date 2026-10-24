//
//  LLMSettingsView.swift
//  BraineeApp
//
//  «Профиль → Настройки → LLM» (LLM-1): ключ OpenRouter (Keychain) и модель (UserDefaults).
//  Ключ после сохранения не показывается целиком — только последние 4 символа.

import SwiftUI

struct LLMSettingsView: View {
    private let secrets = SecretStore.shared

    @State private var savedKeyMask: String?
    @State private var keyInput = ""
    @State private var isReplacingKey = false
    @State private var showingDeleteConfirm = false
    @State private var keyError: String?

    @State private var modelInput = LLMSettings.model()
    @State private var savedModel = LLMSettings.model()
    @State private var modelError: String?

    @State private var keyInfo: OpenRouterKeyInfo?
    @State private var keyInfoError: String?
    @State private var isChecking = false
    @State private var checkResult: CheckResult?
    @State private var dayPlanConsent = DayPlanService.hasConsent()
    @State private var matrixConsent = MatrixReviewService.hasConsent()

    private enum CheckResult: Equatable {
        case success(String)
        case failure(String)
    }

    @FocusState private var focusedField: Field?

    private enum Field {
        case key, model
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Space.sectionGap) {
                GroupedSection(title: "Ключ OpenRouter") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        if let savedKeyMask, !isReplacingKey {
                            savedKeyRow(savedKeyMask)
                        } else {
                            keyInputRow
                        }
                        if let keyError {
                            Text(keyError)
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.danger)
                        }
                        Text("Ключ хранится только в Keychain этого iPhone: не попадает в бэкап и не синхронизируется. После переустановки приложения его нужно ввести заново.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Link("Создать ключ на openrouter.ai", destination: LLMSettings.keysPageURL)
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Space.x3)
                }

                GroupedSection(title: "Модель") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        HStack(spacing: DesignSystem.Space.x2) {
                            inputField {
                                TextField(LLMSettings.defaultModel, text: $modelInput)
                                    .focused($focusedField, equals: .model)
                                    .submitLabel(.done)
                                    .onSubmit(saveModel)
                            }
                            if modelInput != savedModel {
                                Button("Сохранить", action: saveModel)
                                    .font(DesignSystem.Typography.body(15))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }
                        if let modelError {
                            Text(modelError)
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.danger)
                        }
                        Text("Идентификатор модели OpenRouter, например `openrouter/auto` (автовыбор) или модель с суффиксом `:free`.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Link("Каталог моделей", destination: LLMSettings.modelsCatalogURL)
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Space.x3)
                }

                if savedKeyMask != nil {
                    connectionSection
                }

                if dayPlanConsent {
                    GroupedSection(title: "План дня") {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                            Text("Разрешено отправлять в OpenRouter названия задач на сегодня и просроченных и занятое время сегодня (без названий встреч).")
                                .font(DesignSystem.Typography.body(15))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Button("Отозвать разрешение") {
                                DayPlanService.revokeConsent()
                                dayPlanConsent = false
                            }
                            .font(DesignSystem.Typography.body(15))
                            .foregroundStyle(DesignSystem.Colors.danger)
                            .buttonStyle(.plain)
                            Text("После отзыва «План дня» снова спросит разрешение перед отправкой.")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Space.x3)
                    }
                }

                if matrixConsent {
                    GroupedSection(title: "Матрица") {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                            Text("Разрешено отправлять в OpenRouter названия задач без срока.")
                                .font(DesignSystem.Typography.body(15))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Button("Отозвать разрешение") {
                                MatrixReviewService.revokeConsent()
                                matrixConsent = false
                            }
                            .font(DesignSystem.Typography.body(15))
                            .foregroundStyle(DesignSystem.Colors.danger)
                            .buttonStyle(.plain)
                            Text("После отзыва «Матрица» снова спросит разрешение перед отправкой.")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Space.x3)
                    }
                }

                Text("Провайдер — OpenRouter. Наружу отправляется только то, что нужно конкретному действию; приложение работает и без LLM.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("LLM")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
        .onAppear {
            reloadKey()
            dayPlanConsent = DayPlanService.hasConsent()
            matrixConsent = MatrixReviewService.hasConsent()
        }
        .task(id: savedKeyMask) { await loadKeyInfo() }
        .dismissOnTabLeave($showingDeleteConfirm)
        .alert("Удалить ключ?", isPresented: $showingDeleteConfirm) {
            Button("Удалить", role: .destructive, action: deleteKey)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Ключ будет удалён из Keychain этого iPhone. Функции LLM перестанут работать, пока не введёте новый.")
        }
    }

    private func savedKeyRow(_ mask: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            HStack {
                Text("Сохранён")
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text(mask)
                    .font(DesignSystem.Typography.data())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            HStack(spacing: DesignSystem.Space.x4) {
                Button("Заменить") {
                    keyError = nil
                    isReplacingKey = true
                    focusedField = .key
                }
                .foregroundStyle(DesignSystem.Colors.accent)
                Button("Удалить") { showingDeleteConfirm = true }
                    .foregroundStyle(DesignSystem.Colors.danger)
            }
            .font(DesignSystem.Typography.body(15))
            .buttonStyle(.plain)
        }
    }

    private var keyInputRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            inputField {
                SecureField("sk-or-…", text: $keyInput)
                    .focused($focusedField, equals: .key)
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit(saveKey)
            }
            HStack(spacing: DesignSystem.Space.x4) {
                Button("Сохранить ключ", action: saveKey)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .disabled(SecretStore.normalized(keyInput) == nil)
                if isReplacingKey {
                    Button("Отмена") {
                        keyInput = ""
                        keyError = nil
                        isReplacingKey = false
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .font(DesignSystem.Typography.body(15))
            .buttonStyle(.plain)
        }
    }

    private var connectionSection: some View {
        GroupedSection(title: "Соединение") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                HStack(spacing: DesignSystem.Space.x2) {
                    Button("Проверить соединение") {
                        Task { await checkConnection() }
                    }
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .buttonStyle(.plain)
                    .disabled(isChecking)
                    if isChecking {
                        ProgressView()
                    }
                }

                switch checkResult {
                case .success(let text):
                    Label(text, systemImage: "checkmark.circle.fill")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.success)
                case .failure(let text):
                    Label(text, systemImage: "exclamationmark.triangle.fill")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.danger)
                case nil:
                    EmptyView()
                }

                if let keyInfo {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                        Text(keyInfo.summary)
                            .font(DesignSystem.Typography.body(15))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        if let free = keyInfo.freeModelsSummary {
                            Text(free)
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                } else if let keyInfoError {
                    Text("Остаток лимита недоступен: \(keyInfoError)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Text("Остаток — по лимиту, заданному ключу на openrouter.ai. Проверка отправляет модели короткое слово «ping».")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Space.x3)
        }
    }

    private func loadKeyInfo() async {
        keyInfo = nil
        keyInfoError = nil
        guard savedKeyMask != nil, let provider = try? OpenRouterProvider.fromSettings() else { return }
        do {
            keyInfo = try await provider.fetchKeyInfo()
        } catch let error as LLMError {
            keyInfoError = error.userMessage
        } catch {
            keyInfoError = LLMError.invalidResponse.userMessage
        }
    }

    private func checkConnection() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        checkResult = nil
        do {
            let report = try await OpenRouterProvider.fromSettings().checkConnection()
            keyInfo = report.keyInfo
            keyInfoError = nil
            checkResult = .success("Соединение работает · ответила модель \(report.model)")
        } catch let error as LLMError {
            checkResult = .failure(error.userMessage)
        } catch {
            checkResult = .failure(LLMError.invalidResponse.userMessage)
        }
    }

    private func inputField<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(DesignSystem.Typography.body(15))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .fill(DesignSystem.Colors.chip)
            )
    }

    private func reloadKey() {
        let mask = secrets.value(for: .openRouterAPIKey).map(SecretStore.masked)
        if mask != savedKeyMask {
            checkResult = nil
        }
        savedKeyMask = mask
    }

    private func saveKey() {
        guard let key = SecretStore.normalized(keyInput) else {
            keyError = "Ключ не должен быть пустым или содержать пробелы."
            return
        }
        do {
            try secrets.set(key, for: .openRouterAPIKey)
            // Только факт, без значения ключа (п. 16).
            SessionLog.shared.add(.settings, "Ключ OpenRouter сохранён")
            keyInput = ""
            isReplacingKey = false
            focusedField = nil
            keyError = LLMSettings.looksLikeOpenRouterKey(key)
                ? nil
                : "Ключ сохранён, но не похож на ключ OpenRouter (обычно начинается с «sk-or-»)."
            reloadKey()
        } catch {
            keyError = "Не удалось сохранить ключ в Keychain."
        }
    }

    private func deleteKey() {
        do {
            try secrets.remove(.openRouterAPIKey)
            SessionLog.shared.add(.settings, "Ключ OpenRouter удалён")
            keyError = nil
            isReplacingKey = false
            reloadKey()
        } catch {
            keyError = "Не удалось удалить ключ из Keychain."
        }
    }

    private func saveModel() {
        guard LLMSettings.setModel(modelInput) else {
            modelError = "Формат: «провайдер/модель», без пробелов."
            return
        }
        modelInput = LLMSettings.model()
        savedModel = modelInput
        modelError = nil
        checkResult = nil
        focusedField = nil
    }
}
