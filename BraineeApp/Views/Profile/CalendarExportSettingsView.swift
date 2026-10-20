//
//  CalendarExportSettingsView.swift
//  BraineeApp
//
//  Настройка «Экспорт в Календарь» (CAL-2): вкл/выкл без выбора календаря и состояние экспорта.

import SwiftUI
import SwiftData

struct CalendarExportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var isEnabled = CalendarExport.isEnabled
    @State private var access = CalendarExport.store.access
    @State private var isWorking = false
    @State private var calendarSummary: String?
    @State private var lastError: String?
    @State private var lastSync: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Space.sectionGap) {
                GroupedSection(title: "Календарь") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        Toggle(isOn: Binding(
                            get: { isEnabled },
                            set: { newValue in
                                Task { await setEnabled(newValue) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Экспорт в Календарь")
                                    .font(DesignSystem.Typography.body(16))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("Задачи с датой появляются в календаре «\(CalendarEventRules.calendarTitle)» (iCloud, иначе «На iPhone»). Выполненные и удалённые задачи из календаря убираются.")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .tint(DesignSystem.Colors.accent)
                        .disabled(isWorking)

                        if access == .denied || access == .writeOnly {
                            Text("Нет полного доступа к Календарю. Разрешите его в настройках устройства: BraineeApp → Календари → Полный доступ.")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Button("Открыть настройки устройства") {
                                AppNotifications.openSystemSettings()
                            }
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                    .padding(DesignSystem.Space.x3)
                }

                if isEnabled {
                    GroupedSection(title: "Состояние") {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                            statusRow("Календарь", calendarSummary ?? "будет создан при следующем изменении")
                            if let lastSync {
                                statusRow("Обновлено", lastSync.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let lastError {
                                Text(lastError)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(DesignSystem.Space.x3)
                    }
                }

                Text("Экспорт односторонний: изменения события в Календаре не попадают в задачу и заменяются данными задачи при следующем обновлении (после изменений в приложении или при его открытии). При выключении календарь «\(CalendarEventRules.calendarTitle)» и события остаются — удалить календарь можно в приложении Календарь.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("Календарь")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            // Вернулись из настроек устройства: доступ мог появиться или пропасть.
            if phase == .active {
                CalendarExport.syncIfEnabled(context: modelContext)
                reload()
            }
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func setEnabled(_ newValue: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if newValue {
            _ = await CalendarExport.enable(context: modelContext)
        } else {
            CalendarExport.disable()
        }
        reload()
    }

    private func reload() {
        isEnabled = CalendarExport.isEnabled
        access = CalendarExport.store.access
        calendarSummary = CalendarExport.calendarSummary
        lastError = CalendarExport.lastError
        lastSync = CalendarExport.lastSync
    }
}
