//
//  PomodoroActivity.swift
//  BraineeShared
//
//  Помодоро (п. 47, D-47): описание карточки Live Activity — общее для приложения и расширения виджетов.
//  Приложение запускает и обновляет карточку; расширение только рисует её (Dynamic Island, экран блокировки).

import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isFocus: Bool
        var phaseStart: Date
        var phaseEnd: Date
        /// Конец следующей фазы: когда фаза кончилась, а приложение не успело обновить карточку,
        /// она показывает «Фокус окончен · перерыв до 14:37» (D-47 п. 3).
        var nextPhaseEnd: Date
    }

    var focusMinutes: Int
    var breakMinutes: Int
}
#endif

enum PomodoroLink {
    /// Нажатие на карточку: приложение сразу на экране Помодоро.
    static let url = URL(string: "braineeapp://pomodoro")!

    static func isPomodoroURL(_ url: URL) -> Bool {
        url.scheme == self.url.scheme && url.host == self.url.host
    }
}
