//
//  NotificationDeepLinkTests.swift
//  BraineeAppTests
//
//  Разбор UUID задачи из локального пуша (userInfo и identifier).

import Foundation
import Testing
@testable import BraineeApp

struct NotificationDeepLinkTests {

    @Test func userInfo_возвращаетUUIDЗадачи() {
        // В новых пушах UUID лежит в userInfo — по нему открываем карточку.
        let uuid = UUID()
        let userInfo: [AnyHashable: Any] = [
            AppNotifications.taskUUIDUserInfoKey: uuid.uuidString
        ]
        let result = AppNotifications.taskUUID(
            fromUserInfo: userInfo,
            identifier: "unrelated"
        )
        #expect(result == uuid)
    }

    @Test func identifierApproaching_возвращаетUUIDБезUserInfo() {
        // Старые/фолбэк пуши: UUID в хвосте identifier approach.
        let uuid = UUID()
        let identifier = AppNotifications.deadlineApproachingPrefix + uuid.uuidString
        let result = AppNotifications.taskUUID(fromUserInfo: [:], identifier: identifier)
        #expect(result == uuid)
    }

    @Test func identifierApproachingССуффиксомПресета_возвращаетUUID() {
        // Несколько напоминаний: approach.<uuid>.hours1
        let uuid = UUID()
        let identifier = AppNotifications.deadlineApproachingPrefix + uuid.uuidString + ".hours1"
        let result = AppNotifications.taskUUID(fromUserInfo: [:], identifier: identifier)
        #expect(result == uuid)
    }

    @Test func identifierOverdue_возвращаетUUIDБезUserInfo() {
        // Фолбэк для просрочки: UUID в хвосте identifier overdue.
        let uuid = UUID()
        let identifier = AppNotifications.deadlineOverduePrefix + uuid.uuidString
        let result = AppNotifications.taskUUID(fromUserInfo: [:], identifier: identifier)
        #expect(result == uuid)
    }

    @Test func ежедневныйПушБезЗадачи_возвращаетNil() {
        // Общие пуши «Задачи» / «Привычки» не открывают карточку.
        let result = AppNotifications.taskUUID(
            fromUserInfo: [:],
            identifier: "brainee.tasks.daily"
        )
        #expect(result == nil)
    }

    @Test func битыйUUID_возвращаетNil() {
        // Некорректный идентификатор не должен крашить разбор.
        let result = AppNotifications.taskUUID(
            fromUserInfo: [AppNotifications.taskUUIDUserInfoKey: "not-a-uuid"],
            identifier: AppNotifications.deadlineApproachingPrefix + "bad"
        )
        #expect(result == nil)
    }
}
