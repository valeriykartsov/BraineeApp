//
//  SessionLogView.swift
//  BraineeApp
//
//  «Профиль → Дополнительно → Журнал сессии» (п. 16): действия с запуска приложения, новые сверху.

import SwiftUI

struct SessionLogView: View {
    @ObservedObject private var log = SessionLog.shared

    var body: some View {
        ScrollView {
            GroupedSection(title: "С запуска приложения") {
                if log.entries.isEmpty {
                    Text("С запуска приложения действий не было")
                        .font(DesignSystem.Typography.body(15))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Space.x3)
                        .padding(.vertical, DesignSystem.Space.x3)
                } else {
                    // До 500 записей: строки строятся по мере прокрутки.
                    LazyVStack(spacing: 0) {
                        ForEach(Array(log.entries.enumerated()), id: \.element.id) { index, entry in
                            row(entry)
                            if index < log.entries.count - 1 {
                                InsetDivider(leading: DesignSystem.Space.rowIconInset)
                            }
                        }
                    }
                }
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)

            Text("Журнал хранится только в памяти и очищается, когда приложение выгружается. Никуда не отправляется.")
                .font(DesignSystem.Typography.caption(12))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .groupedScreenPadding()
                .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("Журнал сессии")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func row(_ entry: SessionLogEntry) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
            Image(systemName: Self.icon(for: entry.kind))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(DesignSystem.Typography.bodyBold(15))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer(minLength: DesignSystem.Space.x1)
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(DesignSystem.Typography.data(12))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .monospacedDigit()
                }
                if let subject = entry.subject {
                    Text(subject)
                        .font(DesignSystem.Typography.body(14))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }
                ForEach(entry.changes, id: \.self) { change in
                    Text(change)
                        .font(DesignSystem.Typography.caption(13))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2)
        .accessibilityElement(children: .combine)
    }

    private static func icon(for kind: SessionLogEntry.Kind) -> String {
        switch kind {
        case .task: "checklist"
        case .group: "folder"
        case .tag: "tag"
        case .habit: "flame"
        case .profile: "person"
        case .settings: "gearshape"
        case .backup: "externaldrive"
        case .pomodoro: "timer"
        }
    }
}

#Preview {
    NavigationStack {
        SessionLogView()
    }
}
