//
//  PomodoroController.swift
//  BraineeApp
//
//  Помодоро (п. 47, D-47): старт и «Стоп», уведомления на все смены фаз, Live Activity и журнал сессии.
//  Состояние — только `PomodoroSession` в служебном файле; фаза всегда считается от старта (`PomodoroSchedule`).

import Foundation
import Combine
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class PomodoroController: ObservableObject {
    static let shared = PomodoroController()

    @Published private(set) var session: PomodoroSession?

    private let file: PomodoroSessionFile
    private let center: UNUserNotificationCenter
    private let log: SessionLog
    private let now: () -> Date
    /// В тестах false: не запускать настоящую Live Activity в симуляторе.
    private let usesLiveActivity: Bool

    init(
        file: PomodoroSessionFile = .standard(),
        center: UNUserNotificationCenter = .current(),
        log: SessionLog = .shared,
        now: @escaping () -> Date = { .now },
        usesLiveActivity: Bool = true
    ) {
        self.file = file
        self.center = center
        self.log = log
        self.now = now
        self.usesLiveActivity = usesLiveActivity
        session = file.load()
    }

    var isRunning: Bool { session != nil }

    func start(_ mode: PomodoroMode) {
        let session = PomodoroSession(mode: mode, startedAt: now())
        file.save(session)
        self.session = session
        Task { await scheduleNotifications(for: session) }
        startActivity(for: session)
    }

    func stop() {
        session = nil
        file.remove()
        AppNotifications.removePomodoro(center: center)
        endActivities()
    }

    /// При любом пробуждении приложения и смене фазы на экране: журнал пропущенных фокусов,
    /// автоостановка через 8 часов, карточка Live Activity — на текущую фазу.
    func sync() {
        guard var session else {
            endActivities()
            return
        }
        let current = now()
        let completed = PomodoroSchedule.completedFocusCount(session, at: current)
        if completed > session.loggedFocusCount {
            for _ in session.loggedFocusCount..<completed {
                log.add(.pomodoro, "Помодоро: фокус \(session.mode.focusMinutes) мин завершён")
            }
            session.loggedFocusCount = completed
            file.save(session)
            self.session = session
        }
        if PomodoroSchedule.isExpired(session, at: current) {
            stop()
            return
        }
        updateActivity(for: session, at: current)
    }

    private func scheduleNotifications(for session: PomodoroSession) async {
        let settings = NotificationSettings.load()
        guard settings.isEnabled else { return }
        let status = await AppNotifications.authorizationStatus(center: center)
        guard status == .authorized || status == .provisional else { return }
        AppNotifications.schedulePomodoro(session, now: now(), center: center)
    }

    // MARK: - Live Activity

    private func state(for session: PomodoroSession, at date: Date) -> PomodoroActivityAttributes.ContentState {
        let phase = PomodoroSchedule.phase(of: session, at: date)
        let next = PomodoroSchedule.next(after: phase, mode: session.mode)
        return .init(isFocus: phase.isFocus, phaseStart: phase.start, phaseEnd: phase.end, nextPhaseEnd: next.end)
    }

    private func startActivity(for session: PomodoroSession) {
        endActivities()
        guard usesLiveActivity, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = state(for: session, at: session.startedAt)
        let attributes = PomodoroActivityAttributes(
            focusMinutes: session.mode.focusMinutes,
            breakMinutes: session.mode.breakMinutes
        )
        // Без сервера: push-обновлений нет, карточку обновляет приложение, когда просыпается (D-47 п. 3).
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: state.phaseEnd),
            pushType: nil
        )
    }

    private func updateActivity(for session: PomodoroSession, at date: Date) {
        guard usesLiveActivity else { return }
        let state = state(for: session, at: date)
        let activities = Activity<PomodoroActivityAttributes>.activities
        if activities.isEmpty {
            startActivity(for: session)
            return
        }
        for activity in activities where activity.content.state != state {
            Task { await activity.update(ActivityContent(state: state, staleDate: state.phaseEnd)) }
        }
    }

    private func endActivities() {
        guard usesLiveActivity else { return }
        for activity in Activity<PomodoroActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
