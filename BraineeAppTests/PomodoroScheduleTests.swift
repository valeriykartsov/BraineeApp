//
//  PomodoroScheduleTests.swift
//  BraineeAppTests
//
//  Помодоро (п. 47, D-47): фазы от момента старта, смены фаз для уведомлений, завершённые фокусы
//  (журнал при пробуждении), автоостановка через 8 часов, файл сеанса. Старт — фиксированный момент, всё — от него.

import Foundation
import Testing
@testable import BraineeApp

@MainActor
struct PomodoroScheduleTests {
    private let start = Date(timeIntervalSince1970: 1_792_930_043)
    private let file = PomodoroSessionFile(
        url: FileManager.default.temporaryDirectory
            .appendingPathComponent("PomodoroScheduleTests-\(UUID().uuidString)")
            .appendingPathComponent(PomodoroSessionFile.fileName)
    )

    private func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    private func session(_ mode: PomodoroMode = .short) -> PomodoroSession {
        PomodoroSession(mode: mode, startedAt: start)
    }

    // MARK: - Фазы

    // 25/5: фокус 0–25 мин, перерыв 25–30, второй фокус с 30; граница фазы относится к следующей.
    @Test func фазы_25на5() {
        let short = session()
        #expect(PomodoroSchedule.phase(of: short, at: minutes(0)) == PomodoroPhase(isFocus: true, cycle: 0, start: start, end: minutes(25)))
        #expect(PomodoroSchedule.phase(of: short, at: minutes(24.9)).isFocus)
        #expect(PomodoroSchedule.phase(of: short, at: minutes(25)) == PomodoroPhase(isFocus: false, cycle: 0, start: minutes(25), end: minutes(30)))
        #expect(PomodoroSchedule.phase(of: short, at: minutes(30)) == PomodoroPhase(isFocus: true, cycle: 1, start: minutes(30), end: minutes(55)))
        #expect(PomodoroSchedule.phase(of: short, at: minutes(-5)).cycle == 0)
    }

    // 45/15: цикл — час; следующая фаза после фокуса — перерыв, после перерыва — фокус нового цикла.
    @Test func фазы_45на15ИСледующая() {
        let long = session(.long)
        let breakPhase = PomodoroSchedule.phase(of: long, at: minutes(50))
        #expect(breakPhase == PomodoroPhase(isFocus: false, cycle: 0, start: minutes(45), end: minutes(60)))
        #expect(PomodoroSchedule.next(after: breakPhase, mode: .long) == PomodoroPhase(isFocus: true, cycle: 1, start: minutes(60), end: minutes(105)))
        let focus = PomodoroSchedule.phase(of: long, at: minutes(10))
        #expect(PomodoroSchedule.next(after: focus, mode: .long) == breakPhase)
    }

    // MARK: - Уведомления

    // Смены до автоостановки: 32 для 25/5 и 16 для 45/15; последняя — ровно через 8 часов.
    @Test func смены_до8Часов() {
        let short = PomodoroSchedule.upcomingChanges(session(), after: start)
        #expect(short.count == 32)
        #expect(short.first == PomodoroChange(date: minutes(25), focusEnded: true))
        #expect(short[1] == PomodoroChange(date: minutes(30), focusEnded: false))
        #expect(short.last?.date == minutes(480))

        let long = PomodoroSchedule.upcomingChanges(session(.long), after: start)
        #expect(long.count == 16)

        // Через 2 часа остаются только будущие смены.
        #expect(PomodoroSchedule.upcomingChanges(session(), after: minutes(120)).count == 24)
    }

    // Тексты: конец фокуса, конец перерыва, последняя смена — автоостановка.
    @Test func тексты() {
        let focusEnd = PomodoroChange(date: minutes(25), focusEnded: true)
        let breakEnd = PomodoroChange(date: minutes(30), focusEnded: false)
        #expect(AppNotifications.pomodoroBody(focusEnd, mode: .short, isLast: false) == "Фокус 25 мин завершён — перерыв 5 мин")
        #expect(AppNotifications.pomodoroBody(breakEnd, mode: .long, isLast: false) == "Перерыв окончен — снова фокус 45 мин")
        #expect(AppNotifications.pomodoroBody(breakEnd, mode: .short, isLast: true) == "Помодоро завершено: прошло 8 часов")
        #expect(AppNotifications.isPomodoro(identifier: AppNotifications.pomodoroPrefix + "3"))
        #expect(!AppNotifications.isPomodoro(identifier: AppNotifications.deadlineOverduePrefix + "x"))
    }

    // MARK: - Журнал и автоостановка

    // Завершённые фокусы: сколько фокусов кончилось к моменту; после 8 часов — не больше 16.
    @Test func завершённыеФокусы() {
        let short = session()
        #expect(PomodoroSchedule.completedFocusCount(short, at: minutes(10)) == 0)
        #expect(PomodoroSchedule.completedFocusCount(short, at: minutes(25)) == 1)
        #expect(PomodoroSchedule.completedFocusCount(short, at: minutes(29)) == 1)
        #expect(PomodoroSchedule.completedFocusCount(short, at: minutes(56)) == 2)
        #expect(PomodoroSchedule.completedFocusCount(short, at: minutes(600)) == 16)
    }

    // Через 8 часов сеанс закончен.
    @Test func автоостановка() {
        #expect(!PomodoroSchedule.isExpired(session(), at: minutes(479)))
        #expect(PomodoroSchedule.isExpired(session(), at: minutes(480)))
        #expect(PomodoroSchedule.endDate(of: session()) == minutes(480))
    }

    // Пробуждение после сна: в журнал — все пропущенные фокусы по разу; повторный sync не дублирует.
    @Test func пробуждение_журналБезДублей() {
        var current = start
        let log = SessionLog()
        let controller = PomodoroController(file: file, log: log, now: { current }, usesLiveActivity: false)
        file.save(session())
        let restored = PomodoroController(file: file, log: log, now: { current }, usesLiveActivity: false)
        #expect(restored.session == session())

        current = minutes(61)
        restored.sync()
        #expect(log.entries.count == 2)
        #expect(log.entries.first?.title == "Помодоро: фокус 25 мин завершён")
        #expect(file.load()?.loggedFocusCount == 2)

        restored.sync()
        #expect(log.entries.count == 2)
        _ = controller
    }

    // Пробуждение после 8 часов: фокусы дописаны, сеанс закрыт и файл удалён.
    @Test func пробуждениеПосле8Часов_сеансЗакрыт() {
        var current = start
        let log = SessionLog()
        file.save(session())
        let controller = PomodoroController(file: file, log: log, now: { current }, usesLiveActivity: false)

        current = minutes(600)
        controller.sync()

        #expect(log.entries.count == 16)
        #expect(controller.session == nil)
        #expect(file.load() == nil)
    }

    // Битый файл сеанса — сеанса нет.
    @Test func битыйФайл_сеансаНет() throws {
        try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: file.url)
        #expect(file.load() == nil)
    }
}
