//
//  PomodoroView.swift
//  BraineeApp
//
//  «Профиль → Дополнительно → Помодоро» (п. 47, D-47): выбор 25/5 или 45/15, кольцо с отсчётом,
//  «Старт» / «Стоп». Фазы сменяются сами; экран только показывает фазу, посчитанную от старта.

import SwiftUI
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

struct PomodoroView: View {
    @ObservedObject private var controller = PomodoroController.shared
    @State private var mode: PomodoroMode = .short
    @State private var notificationsOff = false
    @State private var activitiesOff = false
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Space.sectionGap) {
                GroupedSection(title: "Режим") {
                    Picker("Режим", selection: $mode) {
                        ForEach(PomodoroMode.allCases) { mode in
                            Text("\(mode.focusMinutes) мин фокус / \(mode.breakMinutes) мин перерыв").tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(controller.isRunning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.x2)
                    .padding(.vertical, DesignSystem.Space.x1)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    timer(at: context.date)
                }

                Button {
                    if controller.isRunning {
                        controller.stop()
                    } else {
                        controller.start(mode)
                        HapticFeedback.success()
                    }
                } label: {
                    Text(controller.isRunning ? "Стоп" : "Старт")
                        .font(DesignSystem.Typography.bodyBold(17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Space.x3)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                                .fill(controller.isRunning ? DesignSystem.Colors.danger : DesignSystem.Colors.accent)
                        )
                }
                .buttonStyle(.plain)

                notes
            }
            .groupedScreenPadding()
            .padding(.vertical, DesignSystem.Space.x3)
        }
        .appScreenBackground()
        .navigationTitle("Помодоро")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let session = controller.session { mode = session.mode }
            controller.sync()
            let settings = NotificationSettings.load()
            let status = await AppNotifications.authorizationStatus()
            notificationsOff = !settings.isEnabled || !(status == .authorized || status == .provisional)
            activitiesOff = !ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    @ViewBuilder
    private func timer(at date: Date) -> some View {
        let session = controller.session
        let phase = session.map { PomodoroSchedule.phase(of: $0, at: date) }
        let remaining = phase.map { max(0, $0.end.timeIntervalSince(date)) } ?? mode.focusSeconds
        let progress = phase.map { 1 - remaining / max($0.duration, 1) } ?? 0
        let color = (phase?.isFocus ?? true) ? DesignSystem.Colors.accent : DesignSystem.Colors.success

        VStack(spacing: DesignSystem.Space.x3) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.chip, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Circle()
                    .fill(color.opacity(0.12))
                    .scaleEffect(pulse && session != nil ? 0.86 : 0.78)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                VStack(spacing: DesignSystem.Space.x1) {
                    AppLogoMark(size: 36)
                    Text(Self.clock(remaining))
                        .font(DesignSystem.Typography.display(48))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                    Text(phase.map { $0.isFocus ? "Фокус" : "Перерыв" } ?? "Готов к фокусу")
                        .font(DesignSystem.Typography.headline(15))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 240, height: 240)
            .onAppear { pulse = true }
            .onChange(of: phase?.end) { _, _ in
                // Фаза сменилась на глазах: журнал и Live Activity — сразу.
                controller.sync()
            }

            if let session, let phase {
                Text("Цикл \(phase.cycle + 1) · до \(phase.end.formatted(date: .omitted, time: .shortened)) · стоп в \(PomodoroSchedule.endDate(of: session).formatted(date: .omitted, time: .shortened))")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Space.x3)
        .accessibilityElement(children: .combine)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text("Фокус и перерыв сменяются сами до «Стоп», на каждой смене — уведомление со звуком. Через 8 часов таймер останавливается сам. История не хранится.")
            if notificationsOff {
                Text("Уведомления выключены — смены фаз будут без звука. Включить: «Профиль → Настройки → Уведомления».")
                    .foregroundStyle(DesignSystem.Colors.danger)
            }
            if activitiesOff {
                Text("Live Activities выключены в настройках iOS — отсчёта в Dynamic Island не будет.")
            }
        }
        .font(DesignSystem.Typography.caption())
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    NavigationStack { PomodoroView() }
}
