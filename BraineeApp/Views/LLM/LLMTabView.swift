//
//  LLMTabView.swift
//  BraineeApp
//
//  Вкладка «LLM» (NAV-1). Без ключа — «Подключите LLM» и переход в настройки;
//  с ключом — чат (LLM-3). Шестерёнка открывает настройки LLM.
//  История чата — только в памяти этого экрана: вкладка не пересоздаётся при переключении,
//  поэтому сообщения живут до закрытия приложения.

import SwiftUI

struct LLMTabView: View {
    var isActive: Bool = true

    @State private var hasKey = LLMProviderFactory.isAvailable
    @State private var showingSettings = false
    @State private var messages: [LLMChatMessage] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("LLM")
                        .font(DesignSystem.Typography.title(24))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    if hasKey && !messages.isEmpty {
                        Button {
                            messages = []
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Новый чат")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Настройки LLM")
                }
                .padding(.horizontal, DesignSystem.Space.screenInset)
                .padding(.top, DesignSystem.Space.x1)
                .padding(.bottom, DesignSystem.Space.x2)

                if hasKey {
                    LLMChatView(messages: $messages)
                } else {
                    Spacer(minLength: 0)
                    placeholder(
                        systemImage: "sparkles",
                        title: "Подключите LLM",
                        message: "Добавьте ключ OpenRouter в настройках. Без ключа приложение работает как обычно."
                    ) {
                        Button("Открыть настройки LLM") { showingSettings = true }
                            .font(DesignSystem.Typography.bodyBold(16))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .padding(.top, DesignSystem.Space.x2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .tint(DesignSystem.Colors.accent)
            .navigationDestination(isPresented: $showingSettings) {
                LLMSettingsView()
                    .toolbar(.visible, for: .navigationBar)
            }
        }
        .onAppear(perform: reloadKey)
        .onChange(of: isActive) { _, active in
            if active { reloadKey() }
        }
        .onChange(of: showingSettings) { _, showing in
            // Вернулись из настроек: ключ могли добавить или удалить.
            if !showing { reloadKey() }
        }
    }

    private func placeholder<Actions: View>(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        VStack(spacing: DesignSystem.Space.x3) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(title)
                .font(DesignSystem.Typography.headline(18))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(message)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            actions()
        }
        .padding(.horizontal, DesignSystem.Space.x8)
    }

    private func reloadKey() {
        hasKey = LLMProviderFactory.isAvailable
    }
}

#Preview {
    LLMTabView()
}
