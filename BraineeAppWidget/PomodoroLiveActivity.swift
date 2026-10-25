//
//  PomodoroLiveActivity.swift
//  BraineeAppWidget
//
//  Помодоро в Dynamic Island и на экране блокировки (п. 47, D-47): логотип, фаза и обратный отсчёт,
//  без кнопок. Отсчёт идёт сам (`Text(timerInterval:)`); когда фаза кончилась, а приложение ещё
//  не проснулось, карточка «устаревает» (`staleDate`) и показывает «Фокус окончен · перерыв до 14:37».
//  Нажатие открывает приложение на экране Помодоро.

import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            PomodoroLockScreenView(context: context)
                .widgetURL(PomodoroLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PomodoroLogo(size: 28)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PomodoroCountdown(state: context.state, isStale: context.isStale)
                        .font(.system(size: 28, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(PomodoroText.caption(context))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                PomodoroLogo(size: 16)
            } compactTrailing: {
                PomodoroCountdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                PomodoroLogo(size: 14)
            }
            .widgetURL(PomodoroLink.url)
        }
    }
}

private struct PomodoroLockScreenView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            PomodoroLogo(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(PomodoroText.title(context))
                    .font(.system(size: 15, weight: .semibold))
                Text(PomodoroText.caption(context))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            PomodoroCountdown(state: context.state, isStale: context.isStale)
                .font(.system(size: 34, weight: .semibold))
        }
        .padding(16)
    }
}

/// Отсчёт до конца фазы; устаревшая карточка — «0:00» не показываем, только подпись.
private struct PomodoroCountdown: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale {
            Image(systemName: "bell.fill")
                .foregroundStyle(PomodoroText.accent)
        } else {
            Text(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(state.isFocus ? PomodoroText.accent : PomodoroText.breakColor)
        }
    }
}

/// Знак из трёх полос, как у иконки приложения.
private struct PomodoroLogo: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: size * 0.12) {
            Capsule().fill(.white).frame(width: size * 0.55, height: size * 0.11)
            Capsule().fill(PomodoroText.accent).frame(width: size * 0.8, height: size * 0.11)
            Capsule().fill(.white).frame(width: size * 0.55, height: size * 0.11)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("BraineeApp")
    }
}

private enum PomodoroText {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.0)
    static let breakColor = Color(red: 0.3, green: 0.75, blue: 0.4)

    static func title(_ context: ActivityViewContext<PomodoroActivityAttributes>) -> String {
        let state = context.state
        if context.isStale {
            return state.isFocus ? "Фокус окончен" : "Перерыв окончен"
        }
        return state.isFocus
            ? "Фокус \(context.attributes.focusMinutes) мин"
            : "Перерыв \(context.attributes.breakMinutes) мин"
    }

    /// Обычная карточка — до какого времени фаза; устаревшая — какая фаза идёт и до скольки.
    static func caption(_ context: ActivityViewContext<PomodoroActivityAttributes>) -> String {
        let state = context.state
        if context.isStale {
            let next = state.isFocus ? "перерыв" : "фокус"
            return "\(title(context)) · \(next) до \(time(state.nextPhaseEnd))"
        }
        return "\(title(context)) · до \(time(state.phaseEnd))"
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
