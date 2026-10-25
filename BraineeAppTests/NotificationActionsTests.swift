//
//  NotificationActionsTests.swift
//  BraineeAppTests
//
//  Кнопки уведомления о задаче (D-46): «Выполнено», «Напомнить через час», «На завтра»,
//  перенос срока, повторы и разбор идентификаторов. onChange — счётчик, «сейчас» — фиксированная дата.

import Foundation
import Testing
import SwiftData
import UserNotifications
@testable import BraineeApp

@MainActor
struct NotificationActionsTests {
    /// Контейнер живёт столько же, сколько тест (см. CLAUDE.md).
    private let container: ModelContainer
    private let calendar: Calendar
    /// «Сейчас» — 25.10.2026 14:30 в фиксированном часовом поясе.
    private let now: Date
    private let snoozeFile: NotificationSnoozesFile

    private final class ChangeCounter {
        var count = 0
    }

    init() throws {
        container = try TestHelpers.makeContainer()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 14, minute: 30))!
        snoozeFile = NotificationSnoozesFile(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("NotificationActionsTests-\(UUID().uuidString)")
                .appendingPathComponent(NotificationSnoozesFile.fileName)
        )
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func task(_ title: String, deadline: Date?, hasTime: Bool) -> TaskItem {
        let task = TaskItem(title: title, deadline: deadline, hasDeadlineTime: hasTime)
        container.mainContext.insert(task)
        return task
    }

    private func service(counter: ChangeCounter, log: SessionLog? = nil) -> TaskService {
        let fixedNow = now
        return TaskService(
            context: container.mainContext,
            onChange: { _ in counter.count += 1 },
            now: { fixedNow },
            log: log ?? SessionLog()
        )
    }

    private func perform(
        _ action: TaskNotificationActions.Action,
        _ task: TaskItem,
        service: TaskService
    ) -> NotificationActionHandler.Outcome {
        NotificationActionHandler.perform(
            action,
            taskUUID: task.uuid,
            notificationTitle: "Напоминание о задаче",
            service: service,
            snoozes: snoozeFile,
            calendar: calendar
        )
    }

    // MARK: - «На завтра»

    // Задача со временем: срок — завтра в то же время; длительность и напоминания не меняются.
    @Test func наЗавтра_соВременем_тоЖеВремяЗавтра() {
        let counter = ChangeCounter()
        let item = task("Отчёт", deadline: date(25, 18, 15), hasTime: true)
        item.durationMinutes = 60
        item.reminderOffsets = [.minutes15]

        #expect(perform(.tomorrow, item, service: service(counter: counter)) == .postponed)

        #expect(item.deadline == date(26, 18, 15))
        #expect(item.hasDeadlineTime)
        #expect(item.durationMinutes == 60)
        #expect(item.reminderOffsets == [.minutes15])
        #expect(counter.count == 1)
    }

    // Без времени остаётся без времени; просроченная на несколько дней — тоже на завтра от сегодня.
    @Test func наЗавтра_просроченнаяБезВремени_завтраОтСегодня() {
        let counter = ChangeCounter()
        let item = task("Коммуналка", deadline: date(21), hasTime: false)

        perform(.tomorrow, item, service: service(counter: counter))

        #expect(item.deadline == date(26))
        #expect(!item.hasDeadlineTime)
    }

    // В журнале — «Задача изменена (из уведомления)» с новым сроком.
    @Test func наЗавтра_журналСПометкойИсточника() throws {
        let log = SessionLog()
        let item = task("Отчёт", deadline: date(25, 9), hasTime: true)

        perform(.tomorrow, item, service: service(counter: ChangeCounter(), log: log))

        let entry = try #require(log.entries.first)
        #expect(entry.title == "Задача изменена (из уведомления)")
        #expect(entry.changes.contains { $0.hasPrefix("Срок") })
    }

    // MARK: - «Выполнено»

    // Задача становится «Готово»; повторное нажатие ничего не меняет и не сохраняет.
    @Test func выполнено_отмечаетОдинРаз() throws {
        let counter = ChangeCounter()
        let log = SessionLog()
        let item = task("Звонок", deadline: date(25, 10), hasTime: true)
        let service = service(counter: counter, log: log)

        #expect(perform(.complete, item, service: service) == .completed)
        #expect(item.isCompleted)
        #expect(item.status == .done)
        #expect(perform(.complete, item, service: service) == .alreadyCompleted)
        #expect(item.isCompleted)
        #expect(counter.count == 1)
        #expect(log.entries.first?.title == "Задача выполнена (из уведомления)")
    }

    // Задача в корзине или удалённая окончательно — кнопки ничего не делают.
    @Test func задачаВКорзинеИлиУдалена_безИзменений() {
        let counter = ChangeCounter()
        let item = task("Удалённая", deadline: date(25, 10), hasTime: true)
        item.isSoftDeleted = true
        let service = service(counter: counter)

        #expect(perform(.complete, item, service: service) == .taskUnavailable)
        #expect(perform(.tomorrow, item, service: service) == .taskUnavailable)
        #expect(!item.isCompleted)
        #expect(item.deadline == date(25, 10))

        let missing = NotificationActionHandler.perform(
            .complete,
            taskUUID: UUID(),
            notificationTitle: "",
            service: service,
            snoozes: snoozeFile,
            calendar: calendar
        )
        #expect(missing == .taskUnavailable)
        #expect(counter.count == 0)
    }

    // MARK: - «Напомнить через час»

    // Повтор через час записан в файл; данные задачи не меняются и не сохраняются.
    @Test func черезЧас_повторВФайлеДанныеНеМеняются() {
        let counter = ChangeCounter()
        let item = task("Звонок", deadline: date(25, 15), hasTime: true)

        let outcome = perform(.snooze, item, service: service(counter: counter))

        #expect(outcome == .snoozed(until: date(25, 15, 30)))
        #expect(snoozeFile.load() == [
            NotificationSnooze(taskUUID: item.uuid, fireDate: date(25, 15, 30), title: "Напоминание о задаче")
        ])
        #expect(item.deadline == date(25, 15))
        #expect(!item.isCompleted)
        #expect(counter.count == 0)
    }

    // Новый повтор той же задачи заменяет прежний.
    @Test func повтор_тойЖеЗадачиЗаменяетПрежний() {
        let id = UUID()
        let first = NotificationSnooze(taskUUID: id, fireDate: date(25, 15), title: "А")
        let other = NotificationSnooze(taskUUID: UUID(), fireDate: date(25, 16), title: "Б")
        let second = NotificationSnooze(taskUUID: id, fireDate: date(25, 17), title: "А")

        let result = NotificationSnoozes.adding(second, to: [first, other])

        #expect(result == [other, second])
    }

    // При пересборке остаются только будущие повторы активных задач.
    @Test func активныеПовторы_безПрошедшихВыполненныхИУдалённых() {
        let open = task("Открыта", deadline: date(25, 15), hasTime: true)
        let done = task("Готова", deadline: date(25, 15), hasTime: true)
        done.status = .done
        let trashed = task("В корзине", deadline: date(25, 15), hasTime: true)
        trashed.isSoftDeleted = true
        let future = date(25, 15, 30)
        let snoozes = [
            NotificationSnooze(taskUUID: open.uuid, fireDate: future, title: ""),
            NotificationSnooze(taskUUID: open.uuid, fireDate: date(25, 14), title: ""),
            NotificationSnooze(taskUUID: done.uuid, fireDate: future, title: ""),
            NotificationSnooze(taskUUID: trashed.uuid, fireDate: future, title: ""),
            NotificationSnooze(taskUUID: UUID(), fireDate: future, title: "")
        ]

        let active = NotificationSnoozes.active(snoozes, tasks: [open, done, trashed], now: now)

        #expect(active == [snoozes[0]])
    }

    // Битый файл повторов не мешает: повторов просто нет.
    @Test func битыйФайлПовторов_пустойСписок() throws {
        try FileManager.default.createDirectory(
            at: snoozeFile.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: snoozeFile.url)

        #expect(snoozeFile.load().isEmpty)
    }

    // MARK: - Категория и идентификаторы

    // Три кнопки; меняющие задачу просят разблокировать, ни одна не открывает приложение.
    @Test func категория_триКнопкиБезОткрытияПриложения() {
        let category = TaskNotificationActions.category
        #expect(category.identifier == TaskNotificationActions.categoryIdentifier)
        #expect(category.actions.map(\.title) == ["Выполнено", "Напомнить через час", "На завтра"])
        for action in category.actions {
            #expect(!action.options.contains(.foreground))
        }
        #expect(TaskNotificationActions.Action.complete.options.contains(.authenticationRequired))
        #expect(TaskNotificationActions.Action.tomorrow.options.contains(.authenticationRequired))
        #expect(!TaskNotificationActions.Action.snooze.options.contains(.authenticationRequired))
    }

    // Из идентификатора повтора достаётся uuid задачи.
    @Test func идентификаторПовтора_uuidЗадачи() {
        let id = UUID()
        let result = AppNotifications.taskUUID(fromUserInfo: [:], identifier: AppNotifications.snoozePrefix + id.uuidString)
        #expect(result == id)
    }
}
