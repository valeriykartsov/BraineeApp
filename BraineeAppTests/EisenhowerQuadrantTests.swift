//
//  EisenhowerQuadrantTests.swift
//  BraineeAppTests
//
//  Правила матрицы: срочность по дедлайну ≤2 дня / просрочка, важность high/highest.

import Foundation
import Testing
@testable import BraineeApp

struct EisenhowerQuadrantTests {

    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        // Фиксированная «сегодня» для стабильных тестов.
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
    }

    private func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    @Test func просроченнаяВажная_сделать() {
        // Просрочка + высокий приоритет → «Сделать».
        let q = EisenhowerQuadrant.classify(
            deadline: day(offset: -1),
            priority: .high,
            isCompleted: false,
            now: now,
            calendar: calendar
        )
        #expect(q == .doFirst)
    }

    @Test func дедлайнЧерезДваДняВажная_сделать() {
        // Граница срочности: сегодня+2 при high → doFirst.
        let q = EisenhowerQuadrant.classify(
            deadline: day(offset: 2),
            priority: .highest,
            now: now,
            calendar: calendar
        )
        #expect(q == .doFirst)
    }

    @Test func дедлайнЧерезТриДняВажная_запланировать() {
        // >2 дней + важно → schedule.
        let q = EisenhowerQuadrant.classify(
            deadline: day(offset: 3),
            priority: .high,
            now: now,
            calendar: calendar
        )
        #expect(q == .schedule)
    }

    @Test func безДедлайнаВажная_запланировать() {
        // Нет дедлайна = не срочно.
        let q = EisenhowerQuadrant.classify(
            deadline: nil,
            priority: .highest,
            now: now,
            calendar: calendar
        )
        #expect(q == .schedule)
    }

    @Test func срочнаяНизкийПриоритет_делегировать() {
        let q = EisenhowerQuadrant.classify(
            deadline: day(offset: 0),
            priority: .low,
            now: now,
            calendar: calendar
        )
        #expect(q == .delegate)
    }

    @Test func безДедлайнаСредний_убрать() {
        let q = EisenhowerQuadrant.classify(
            deadline: nil,
            priority: .medium,
            now: now,
            calendar: calendar
        )
        #expect(q == .eliminate)
    }

    @Test func выполненнаяПросрочкаНеСрочнаяПоOverdue() {
        // Выполненная не считается просроченной в TaskItem.isOverdue;
        // классификатор тоже не помечает completed overdue как срочную через ветку overdue.
        // Дедлайн вчера + completed → не urgent (deadlineDay < today но isCompleted).
        let q = EisenhowerQuadrant.classify(
            deadline: day(offset: -1),
            priority: .high,
            isCompleted: true,
            now: now,
            calendar: calendar
        )
        #expect(q == .schedule)
    }

    @Test func сегодняВремяУжеПрошло_срочная() {
        // Дедлайн сегодня с прошедшим временем → срочно (просрочка по времени).
        let deadline = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        let later = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!
        #expect(
            EisenhowerQuadrant.isUrgent(
                deadline: deadline,
                hasDeadlineTime: true,
                isCompleted: false,
                now: later,
                calendar: calendar
            )
        )
    }
}
