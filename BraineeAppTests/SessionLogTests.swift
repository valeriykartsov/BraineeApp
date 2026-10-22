//
//  SessionLogTests.swift
//  BraineeAppTests
//
//  Журнал сессии (п. 16): лимит, строки изменений, одно действие — ровно одна запись.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct SessionLogTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private let log = SessionLog()
    private let utc = TimeZone(identifier: "UTC")!

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private var tasks: TaskService {
        TaskService(context: container.mainContext, onChange: { _ in }, log: log)
    }

    private func form(for task: TaskItem) -> TaskFormData {
        TaskFormData(
            title: task.title,
            deadline: task.deadline,
            hasDeadlineTime: task.hasDeadlineTime,
            reminderOffsets: task.reminderOffsets,
            priority: task.priority,
            status: task.status,
            taskDetails: task.taskDetails,
            selectedTags: task.tags ?? []
        )
    }

    private func makeTask(title: String = "Отчёт") -> TaskItem {
        let task = TaskItem(title: title, priority: .medium, taskDetails: "черновик")
        container.mainContext.insert(task)
        return task
    }

    // MARK: - Журнал

    // Больше 500 записей не хранится: старые вытесняются, новые сверху.
    @Test func лимит_500ПоследнихНовыеСверху() {
        for index in 0..<(SessionLog.maxEntries + 20) {
            log.add(.task, "Событие \(index)")
        }
        #expect(log.entries.count == SessionLog.maxEntries)
        #expect(log.entries.first?.title == "Событие \(SessionLog.maxEntries + 19)")
        #expect(log.entries.last?.title == "Событие 20")
    }

    // MARK: - Строки изменений задачи

    // Изменённые поля — «было → стало»; описание — только факт, даже когда его убрали.
    @Test func diffЗадачи_поляБылоСталоОписаниеБезТекста() {
        let task = makeTask()
        let before = TaskLogFields(task)
        task.title = "Отчёт за квартал"
        task.priority = .high
        task.deadline = Date(timeIntervalSince1970: 1_792_000_000)
        task.taskDetails = ""

        let changes = TaskLogFields.changes(from: before, to: TaskLogFields(task), timeZone: utc)

        #expect(changes == [
            "Название: «Отчёт» → «Отчёт за квартал»",
            "Срок: нет → 14.10.2026",
            "Приоритет: Средний → Высокий",
            "Описание изменено"
        ])
    }

    // MARK: - Сервисы: одно действие — одна запись

    // Изменение задачи через форму — одна запись со строками; сохранение без правок — ни одной.
    @Test func изменениеЗадачи_однаЗаписьБезПравокНиОдной() {
        let task = makeTask()
        tasks.update(task, from: form(for: task))
        #expect(log.entries.isEmpty)

        var edited = form(for: task)
        edited.priority = .high
        tasks.update(task, from: edited)

        #expect(log.entries.count == 1)
        #expect(log.entries.first?.title == "Задача изменена")
        #expect(log.entries.first?.subject == "Отчёт")
        #expect(log.entries.first?.changes == ["Приоритет: Средний → Высокий"])
    }

    // Перенос в другую папку пишется как смена папки; повторный перенос в ту же — нет.
    @Test func переносЗадачи_толькоСменаПапки() {
        let task = makeTask()
        let group = TaskGroup(name: "Работа", category: .tasks, sortOrder: 0)
        container.mainContext.insert(group)

        tasks.move(task, to: group)
        tasks.move(task, to: group)

        #expect(log.entries.count == 1)
        #expect(log.entries.first?.changes == ["Папка: Входящие → «Работа»"])
    }

    // Отметка, корзина, восстановление и окончательное удаление — по одной записи.
    @Test func жизненныйЦиклЗадачи_поОднойЗаписиНаДействие() {
        let task = makeTask()
        tasks.toggleCompletion(task)
        tasks.softDelete(task)
        tasks.restore(task)
        tasks.softDelete(task)
        tasks.permanentlyDelete([task])

        #expect(log.entries.map(\.title) == [
            "Удалено из корзины навсегда",
            "Задача удалена в корзину",
            "Задача восстановлена из корзины",
            "Задача удалена в корзину",
            "Задача выполнена"
        ])
    }

    // Отметка привычки пишется, перестановка привычек — нет.
    @Test func привычки_отметкаПишетсяПерестановкаНет() throws {
        let habits = HabitService(context: container.mainContext, onChange: { _ in }, log: log)
        let first = try #require(habits.create(title: "Зарядка"))
        let second = try #require(habits.create(title: "Чтение"))
        let creations = log.entries.count

        habits.finishDrag(payload: [second.uuid.uuidString], onto: first.uuid)
        #expect(log.entries.count == creations)

        habits.toggle(first, on: .now)
        #expect(log.entries.count == creations + 1)
        #expect(log.entries.first?.title == "Привычка отмечена")
        #expect(log.entries.first?.subject == "Зарядка")
    }

    // Аватар — только факт смены, без данных; без изменений — записи нет.
    @Test func профиль_аватарТолькоФакт() {
        let profile = ProfileService(context: container.mainContext, onChange: { _ in }, log: log)
        profile.update(name: "", age: nil, gender: .unspecified, avatarData: nil)
        #expect(log.entries.isEmpty)

        profile.update(name: "Валера", age: nil, gender: .unspecified, avatarData: Data([1, 2, 3]))
        #expect(log.entries.count == 1)
        #expect(log.entries.first?.changes == ["Имя: «» → «Валера»", "Аватар изменён"])
    }
}

/// Наблюдатель за настройками: запись только при реальном изменении, без двойных записей.
@MainActor
struct SettingsChangeObserverTests {
    private let defaults: UserDefaults
    private let log = SessionLog()
    private let observer: SettingsChangeObserver

    init() {
        let name = "SettingsChangeObserverTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        observer = SettingsChangeObserver(defaults: defaults, log: log)
        observer.start()
    }

    // Смена темы — одна запись «Системная → Тёмная»; запись того же значения — ни одной.
    @Test func тема_однаЗаписьПовторНеПишется() {
        defaults.set(AppTheme.dark.rawValue, forKey: "appTheme")
        observer.check()
        defaults.set(AppTheme.dark.rawValue, forKey: "appTheme")
        observer.check()

        #expect(log.entries.count == 1)
        #expect(log.entries.first?.subject == "Тема")
        #expect(log.entries.first?.changes == ["Системная → Тёмная"])
    }

    // Наклейка на иконке пишется в два ключа (блок уведомлений и копия для таб-бара) — запись одна.
    @Test func наклейка_дваКлючаОднаЗапись() {
        var settings = NotificationSettings.default
        settings.iconBadgeMode = .off
        settings.save(defaults: defaults)
        observer.check()

        #expect(log.entries.count == 1)
        #expect(log.entries.first?.subject == "Уведомления")
        #expect(log.entries.first?.changes == ["Наклейка на иконке: Просроченные → Выкл"])
    }

    // Служебные ключи (время синхронизации календаря) в журнал не попадают.
    @Test func служебныйКлюч_неПишется() {
        defaults.set(Date(), forKey: CalendarExport.lastSyncKey)
        observer.check()
        #expect(log.entries.isEmpty)
    }
}
