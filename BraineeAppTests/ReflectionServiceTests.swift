//
//  ReflectionServiceTests.swift
//  BraineeAppTests
//
//  LLM-5 «Итоги» (D-31): цифры за сегодня и последние 7 дней на граничных датах, в модель уходят только числа.
//  «Сейчас» — среда 21.10.2026 12:00 (Москва); 7 дней — с 14.10 12:00 (п. 49).

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct ReflectionServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private static let now = LLMTestSupport.now

    /// Календарь с понедельником как первым днём недели (как у русской локали).
    private static var calendar: Calendar {
        var calendar = LLMTestSupport.calendar
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        LLMTestSupport.date(2026, month, day, hour)
    }

    private func insert(_ task: TaskItem) -> TaskItem {
        container.mainContext.insert(task)
        return task
    }

    private func compute(_ period: ReflectionPeriod, tasks: [TaskItem] = [], habits: [Habit] = []) -> ReflectionStats {
        ReflectionService.compute(tasks: tasks, habits: habits, period: period, now: Self.now, calendar: Self.calendar)
    }

    // MARK: - Период

    // Сегодня — с начала дня; 7 дней — ровно 7 суток до момента запроса, не с начала недели;
    // привычки за 7 дней — сегодня и 6 предыдущих дней.
    @Test func период_началоДняИ7Суток() {
        let calendar = Self.calendar
        #expect(ReflectionPeriod.today.start(now: Self.now, calendar: calendar) == date(10, 21, 0))
        #expect(ReflectionPeriod.last7Days.start(now: Self.now, calendar: calendar) == date(10, 14, 12))
        #expect(ReflectionPeriod.last7Days.start(now: date(10, 19, 8), calendar: calendar) == date(10, 12, 8))
        #expect(ReflectionPeriod.last7Days.firstHabitDay(now: Self.now, calendar: calendar) == date(10, 15, 0))
        #expect(ReflectionPeriod.last7Days.rawValue == "week")
    }

    // Границы периода — в цифрах и в выдаче: «14 октября 12:00 – 21 октября 12:00».
    @Test func период_интервалВВыдаче() {
        let stats = compute(.last7Days)
        #expect(stats.periodStart == date(10, 14, 12))
        #expect(stats.periodEnd == Self.now)
        #expect(stats.days == 7)
        #expect(stats.intervalText(timeZone: Self.calendar.timeZone) == "14 октября 12:00 – 21 октября 12:00")
    }

    // MARK: - Задачи

    // Выполненные считаются по дате выполнения: вчерашняя — в 7 днях, но не в «сегодня»;
    // 14.10 в 13:00 — внутри 7 суток, 14.10 в 11:00 — уже нет.
    @Test func задачи_выполненныеПоДатеВыполнения() {
        let tasks = [
            insert(TaskItem(title: "Сегодня", status: .done, createdAt: date(10, 1), completedAt: date(10, 21, 9))),
            insert(TaskItem(title: "Полночь сегодня", status: .done, createdAt: date(10, 1), completedAt: date(10, 21, 0))),
            insert(TaskItem(title: "Вчера", status: .done, createdAt: date(10, 1), completedAt: date(10, 20, 23))),
            insert(TaskItem(title: "7 суток назад, позже", status: .done, createdAt: date(10, 1), completedAt: date(10, 14, 13))),
            insert(TaskItem(title: "7 суток назад, раньше", status: .done, createdAt: date(10, 1), completedAt: date(10, 14, 11))),
        ]
        #expect(compute(.today, tasks: tasks).completed == 2)
        #expect(compute(.last7Days, tasks: tasks).completed == 4)
    }

    // Созданные — по дате создания, в том числе ушедшие в корзину; в «не выполнено сейчас» корзины нет (п. 49).
    @Test func задачи_созданныеИУдалённые() {
        let tasks = [
            insert(TaskItem(title: "Новая", createdAt: date(10, 21, 8))),
            insert(TaskItem(title: "Понедельник", createdAt: date(10, 19, 0))),
            insert(TaskItem(title: "Старше 7 суток", createdAt: date(10, 14, 11))),
            insert(TaskItem(title: "В корзине", createdAt: date(10, 21, 9), isSoftDeleted: true, deletedAt: date(10, 21, 10))),
        ]
        let today = compute(.today, tasks: tasks)
        #expect(today.created == 2)
        #expect(today.active == 3)
        #expect(compute(.last7Days, tasks: tasks).created == 3)
    }

    // Выполненная в периоде и затем удалённая в корзину задача считается выполненной (и по приоритету);
    // в «просрочено» корзина не входит; выполненная раньше 7 суток — не в периоде (п. 49).
    @Test func задачи_вКорзинеУчитываютсяЗаПериод() {
        let tasks = [
            insert(TaskItem(title: "Готова и удалена", priority: .high, status: .done, createdAt: date(10, 1),
                            isSoftDeleted: true, deletedAt: date(10, 21, 10), completedAt: date(10, 21, 9))),
            insert(TaskItem(title: "Готова давно", status: .done, createdAt: date(10, 1),
                            isSoftDeleted: true, deletedAt: date(10, 21, 10), completedAt: date(10, 12))),
            insert(TaskItem(title: "Просрочена и удалена", deadline: date(10, 20, 0), createdAt: date(10, 1),
                            isSoftDeleted: true, deletedAt: date(10, 21, 10))),
        ]
        let today = compute(.today, tasks: tasks)
        #expect(today.completed == 1)
        #expect(today.completedHigh == 1)
        #expect(today.active == 0)
        #expect(today.overdue == 0)
        #expect(compute(.last7Days, tasks: tasks).completed == 1)
    }

    // Просрочка — на текущий момент: вчерашний срок без времени и сегодняшний час, который уже прошёл.
    @Test func задачи_просроченныеНаСейчас() {
        let tasks = [
            insert(TaskItem(title: "Вчера", deadline: date(10, 20, 0), createdAt: date(10, 1))),
            insert(TaskItem(title: "Сегодня 10:00", deadline: date(10, 21, 10), hasDeadlineTime: true, createdAt: date(10, 1))),
            insert(TaskItem(title: "Сегодня без времени", deadline: date(10, 21, 0), createdAt: date(10, 1))),
            insert(TaskItem(title: "Сегодня 15:00", deadline: date(10, 21, 15), hasDeadlineTime: true, createdAt: date(10, 1))),
            insert(TaskItem(title: "Выполнена вчера", deadline: date(10, 19, 0), status: .done, createdAt: date(10, 1), completedAt: date(10, 20))),
        ]
        let stats = compute(.today, tasks: tasks)
        #expect(stats.overdue == 2)
        #expect(stats.active == 4)
    }

    // Выполненные за период раскладываются по приоритетам.
    @Test func задачи_выполненныеПоПриоритетам() {
        let done = { (priority: TaskPriority) in
            self.insert(TaskItem(title: "З", priority: priority, status: .done, createdAt: self.date(10, 1), completedAt: self.date(10, 21, 9)))
        }
        let stats = compute(.today, tasks: [done(.highest), done(.high), done(.high), done(.low)])
        #expect(stats.completedHighest == 1)
        #expect(stats.completedHigh == 2)
        #expect(stats.completedMedium == 0)
        #expect(stats.completedLow == 1)
    }

    // MARK: - Привычки

    // Отметки за период из возможных: привычка × дни с её создания по сегодня.
    @Test func привычки_отметкиИзВозможных() {
        let old = Habit(title: "Старая", createdAt: date(9, 1), completedDayKeys: ["2026-10-21", "2026-10-20", "2026-10-15"])
        let fresh = Habit(title: "Новая", createdAt: date(10, 21, 7), completedDayKeys: [])
        container.mainContext.insert(old)
        container.mainContext.insert(fresh)

        let today = compute(.today, habits: [old, fresh])
        #expect(today.habits == 2)
        #expect(today.habitCheckins == 1)
        #expect(today.habitPossible == 2)
        #expect(today.habitRatePercent == 50)

        // 7 дней — 15…21.10: у старой 7 дней и 3 отметки (15, 20, 21), у новой — 1 день.
        let week = compute(.last7Days, habits: [old, fresh])
        #expect(week.days == 7)
        #expect(week.habitCheckins == 3)
        #expect(week.habitPossible == 8)
        #expect(week.habitRatePercent == 38)
    }

    // Без привычек процента нет.
    @Test func привычки_нет_процентаНет() {
        #expect(compute(.last7Days).habitRatePercent == nil)
    }

    // MARK: - Запрос и ответ

    // D-31: в запросе только числа — ни названий задач, ни названий привычек.
    @Test func запрос_толькоЧисла() {
        let task = insert(TaskItem(title: "Секретная задача", status: .done, createdAt: date(10, 21, 8), completedAt: date(10, 21, 9)))
        task.taskDetails = "Личное описание"
        let habit = Habit(title: "Тайная привычка", createdAt: date(9, 1), completedDayKeys: ["2026-10-21"])
        container.mainContext.insert(habit)

        let stats = compute(.last7Days, tasks: [task], habits: [habit])
        let request = ReflectionService.makeRequest(stats: stats)
        let everything = request.messages.map(\.content).joined(separator: "\n")
        #expect(request.messages.count == 2)
        #expect(request.messages[0].content.hasPrefix(ReflectionService.modeMarker))
        #expect(!everything.contains("Секретная задача"))
        #expect(!everything.contains("Личное описание"))
        #expect(!everything.contains("Тайная привычка"))
        #expect(request.messages[1].content.contains("Выполнено задач: 1"))
        #expect(request.messages[1].content.contains("последние 7 дней до момента запроса"))
        #expect(request.messages[1].content.contains("отметок: 1 из 7 возможных (14%)"))
        #expect(!everything.contains("октября"))
    }

    // Ответ модели очищается от markdown; пустой ответ — ошибка.
    @Test func ответ_очисткаИПустой() throws {
        #expect(try ReflectionService.parse("  **Хороший день.** Так держать.\n") == "Хороший день. Так держать.")
        #expect(throws: LLMError.emptyResponse) { try ReflectionService.parse("  ``` ``` ") }
    }

    // Генератор: один запрос, текст модели; ошибка модели передаётся как есть.
    @Test func генератор_текстИОшибка() async throws {
        let stats = compute(.today)
        let provider = StubLLMProvider(.success("Спокойный день."))
        #expect(try await ReflectionGenerator(provider: provider).reflection(for: stats) == "Спокойный день.")
        #expect(provider.requests.count == 1)

        provider.reply = .failure(.insufficientCredits)
        do {
            _ = try await ReflectionGenerator(provider: provider).reflection(for: stats)
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? LLMError == .insufficientCredits)
        }
    }

    // MARK: - Встречи (D-44)

    private func meeting(
        _ title: String, _ start: Date, _ end: Date, allDay: Bool = false, calendarTitle: String = "Работа"
    ) -> CalendarMeeting {
        CalendarMeeting(id: title, title: title, start: start, end: end, isAllDay: allDay, calendarTitle: calendarTitle)
    }

    /// 7 дней — с 14.10 12:00 до «сейчас» — среды 21.10, 12:00; встреча 14.10 утром — уже за границей.
    private var weekEvents: [CalendarMeeting] {
        [
            meeting("Старше 7 суток", LLMTestSupport.date(2026, 10, 14, 10), LLMTestSupport.date(2026, 10, 14, 11)),
            meeting("Планёрка", LLMTestSupport.date(2026, 10, 19, 10), LLMTestSupport.date(2026, 10, 19, 11)),
            meeting("Разбор", LLMTestSupport.date(2026, 10, 20, 14), LLMTestSupport.date(2026, 10, 20, 15, 30)),
            meeting("Праздник", LLMTestSupport.date(2026, 10, 20), LLMTestSupport.date(2026, 10, 21), allDay: true),
            meeting("Задача", LLMTestSupport.date(2026, 10, 20, 9), LLMTestSupport.date(2026, 10, 20, 10),
                    calendarTitle: CalendarEventRules.calendarTitle),
            meeting("Идёт сейчас", LLMTestSupport.date(2026, 10, 21, 11, 30), LLMTestSupport.date(2026, 10, 21, 12, 30)),
            meeting("Вечером", LLMTestSupport.date(2026, 10, 21, 15), LLMTestSupport.date(2026, 10, 21, 16)),
        ]
    }

    // Считаются встречи с начала периода до «сейчас»: без событий на весь день и календаря «BraineeApp»;
    // время — только часть, попавшая в период (идущая встреча — до «сейчас»).
    @Test func встречи_числоИВремяЗаПериод() {
        let stats = ReflectionService.compute(
            tasks: [], habits: [], period: .last7Days, meetingEvents: weekEvents, now: Self.now, calendar: Self.calendar
        )

        #expect(stats.meetings == 3)
        #expect(stats.meetingMinutes == 180)
        #expect(stats.meetingsText == "3 (3 ч)")
    }

    // В запрос — только два числа о встречах, без названий и календарей; без доступа строки нет.
    @Test func встречи_вЗапросеТолькоЧисла() {
        let stats = ReflectionService.compute(
            tasks: [], habits: [], period: .last7Days, meetingEvents: weekEvents, now: Self.now, calendar: Self.calendar
        )
        let everything = ReflectionService.makeRequest(stats: stats).messages.map(\.content).joined(separator: "\n")

        #expect(everything.contains("Встреч в календаре: 3, во встречах: 3 ч."))
        for secret in ["Планёрка", "Разбор", "Идёт сейчас", "Работа"] {
            #expect(!everything.contains(secret), "\(secret)")
        }

        let unavailable = compute(.last7Days)
        #expect(unavailable.meetings == nil)
        #expect(unavailable.meetingsText == nil)
        #expect(!ReflectionService.numbersMessage(unavailable).contains("Встреч"))
    }

    // Время во встречах словами: минуты, часы, часы с минутами.
    @Test func встречи_времяСловами() {
        #expect(ReflectionService.meetingTimeText(minutes: 0) == "0 мин")
        #expect(ReflectionService.meetingTimeText(minutes: 45) == "45 мин")
        #expect(ReflectionService.meetingTimeText(minutes: 120) == "2 ч")
        #expect(ReflectionService.meetingTimeText(minutes: 150) == "2 ч 30 мин")
    }
}
