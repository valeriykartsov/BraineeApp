//
//  PomodoroSchedule.swift
//  BraineeApp
//
//  Помодоро (п. 47, D-47): сеанс — это только режим и время старта; фаза в любой момент считается
//  от старта (цикл = фокус + перерыв), поэтому приложение после выгрузки сразу показывает верную фазу.
//  Сеанс сам заканчивается через 8 часов. Чистые функции — без таймеров, уведомлений и Live Activity.

import Foundation

enum PomodoroMode: String, Codable, CaseIterable, Identifiable {
    case short = "25-5"
    case long = "45-15"

    var id: String { rawValue }

    var focusMinutes: Int {
        switch self {
        case .short: 25
        case .long: 45
        }
    }

    var breakMinutes: Int {
        switch self {
        case .short: 5
        case .long: 15
        }
    }

    var title: String { "\(focusMinutes) / \(breakMinutes)" }

    var focusSeconds: TimeInterval { TimeInterval(focusMinutes * 60) }
    var cycleSeconds: TimeInterval { TimeInterval((focusMinutes + breakMinutes) * 60) }
}

struct PomodoroSession: Codable, Equatable {
    var mode: PomodoroMode
    var startedAt: Date
    /// Сколько завершённых фокусов уже записано в журнал сессии (D-47 п. 5).
    var loggedFocusCount: Int = 0
}

struct PomodoroPhase: Equatable {
    var isFocus: Bool
    /// Номер цикла с нуля.
    var cycle: Int
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Смена фазы — для уведомления: конец фокуса или конец перерыва.
struct PomodoroChange: Equatable {
    var date: Date
    var focusEnded: Bool
}

enum PomodoroSchedule {
    /// Автоостановка (D-47 п. 4): столько же iOS держит Live Activity.
    static let maxDuration: TimeInterval = 8 * 60 * 60

    static func endDate(of session: PomodoroSession) -> Date {
        session.startedAt.addingTimeInterval(maxDuration)
    }

    static func isExpired(_ session: PomodoroSession, at now: Date) -> Bool {
        now >= endDate(of: session)
    }

    /// Фаза в момент `now` (до старта — первый фокус).
    static func phase(of session: PomodoroSession, at now: Date) -> PomodoroPhase {
        let mode = session.mode
        let elapsed = max(0, now.timeIntervalSince(session.startedAt))
        let cycle = Int(elapsed / mode.cycleSeconds)
        let cycleStart = session.startedAt.addingTimeInterval(Double(cycle) * mode.cycleSeconds)
        let focusEnd = cycleStart.addingTimeInterval(mode.focusSeconds)
        if now < focusEnd {
            return PomodoroPhase(isFocus: true, cycle: cycle, start: cycleStart, end: focusEnd)
        }
        return PomodoroPhase(
            isFocus: false,
            cycle: cycle,
            start: focusEnd,
            end: cycleStart.addingTimeInterval(mode.cycleSeconds)
        )
    }

    /// Следующая фаза после `phase`.
    static func next(after phase: PomodoroPhase, mode: PomodoroMode) -> PomodoroPhase {
        if phase.isFocus {
            return PomodoroPhase(isFocus: false, cycle: phase.cycle, start: phase.end, end: phase.start.addingTimeInterval(mode.cycleSeconds))
        }
        return PomodoroPhase(isFocus: true, cycle: phase.cycle + 1, start: phase.end, end: phase.end.addingTimeInterval(mode.focusSeconds))
    }

    /// Сколько фокусов закончилось к `now` (не позже автоостановки).
    static func completedFocusCount(_ session: PomodoroSession, at now: Date) -> Int {
        let until = min(now, endDate(of: session))
        let elapsed = until.timeIntervalSince(session.startedAt)
        guard elapsed > 0 else { return 0 }
        let cycles = Int(elapsed / session.mode.cycleSeconds)
        let rest = elapsed - Double(cycles) * session.mode.cycleSeconds
        return cycles + (rest >= session.mode.focusSeconds ? 1 : 0)
    }

    /// Все смены фаз после `now` и до автоостановки — на каждую разовое уведомление.
    static func upcomingChanges(_ session: PomodoroSession, after now: Date) -> [PomodoroChange] {
        let end = endDate(of: session)
        var changes: [PomodoroChange] = []
        var phase = phase(of: session, at: session.startedAt)
        while phase.end <= end {
            if phase.end > now {
                changes.append(PomodoroChange(date: phase.end, focusEnded: phase.isFocus))
            }
            phase = next(after: phase, mode: session.mode)
        }
        return changes
    }
}

/// Сеанс — служебный файл `Application Support/BraineeApp/pomodoro-session.json` (не SwiftData, не бэкап).
struct PomodoroSessionFile {
    static let fileName = "pomodoro-session.json"

    let url: URL

    static func standard() -> PomodoroSessionFile {
        PomodoroSessionFile(
            url: ModelContainerFactory.standardStoreURL
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
        )
    }

    /// Нет файла или он битый — сеанса нет.
    func load() -> PomodoroSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PomodoroSession.self, from: data)
    }

    func save(_ session: PomodoroSession) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(session).write(to: url, options: .atomic)
        } catch {
            print("Pomodoro: save failed: \(error)")
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
