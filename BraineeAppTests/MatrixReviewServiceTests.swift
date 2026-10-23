//
//  MatrixReviewServiceTests.swift
//  BraineeAppTests
//
//  Режим «Матрица» (D-42): какие задачи попадают в запрос и что о них уходит, разбор ответа
//  (действие, горизонт, совет), текст для «Копировать» и «Поделиться», согласие. «Сейчас» — 21.10.2026 12:00.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct MatrixReviewServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private static let now = LLMTestSupport.now
    private static let calendar = LLMTestSupport.calendar

    private func date(_ day: Int, _ hour: Int = 0) -> Date {
        LLMTestSupport.date(2026, 10, day, hour)
    }

    @discardableResult
    private func task(
        _ title: String,
        deadline: Date? = nil,
        priority: TaskPriority = .medium,
        createdDay: Int = 1,
        done: Bool = false,
        deleted: Bool = false
    ) -> TaskItem {
        let item = TaskItem(
            title: title,
            deadline: deadline,
            priority: priority,
            status: done ? .done : .new,
            createdAt: date(createdDay),
            isSoftDeleted: deleted
        )
        container.mainContext.insert(item)
        return item
    }

    // MARK: - Выбор задач

    // Только невыполненные и не удалённые задачи без срока; по приоритету, затем по дате создания.
    @Test func выбор_безСрокаПоПриоритетуИСозданию() {
        let tasks = [
            task("Позже создана", createdDay: 5),
            task("Раньше создана", createdDay: 2),
            task("Важная", priority: .highest, createdDay: 9),
            task("Со сроком", deadline: date(25)),
            task("Выполнена", done: true),
            task("В корзине", deleted: true),
        ]
        #expect(MatrixReviewService.selectTasks(tasks).map(\.title) == ["Важная", "Раньше создана", "Позже создана"])
    }

    // Не больше 30 задач.
    @Test func выбор_неБольше30() {
        let tasks = (1...35).map { task("Задача \($0)") }
        #expect(MatrixReviewService.selectTasks(tasks).count == 30)
    }

    // D-42: номер, название, приоритет и квадрант — без описаний, тегов, папок, подзадач и uuid.
    @Test func запрос_толькоРазрешённыеПоля() throws {
        let group = TaskGroup(name: "Секретная папка")
        let tag = TaskTag(name: "Секретный тег")
        container.mainContext.insert(group)
        container.mainContext.insert(tag)
        let important = task("Обновить резюме", priority: .high)
        important.taskDetails = "Ссылка на старое резюме"
        important.group = group
        important.tags = [tag]
        important.subtasks = [TaskSubtask(title: "Секретная подзадача")]
        let minor = task("Разобрать почту", priority: .low, createdDay: 3)

        let selected = MatrixReviewService.selectTasks([minor, important])
        let items = MatrixReviewService.inputItems(for: selected, now: Self.now, calendar: Self.calendar)
        #expect(items == [
            MatrixReviewInputItem(number: 1, title: "Обновить резюме", priority: .high, quadrant: .schedule),
            MatrixReviewInputItem(number: 2, title: "Разобрать почту", priority: .low, quadrant: .eliminate),
        ])

        let request = try MatrixReviewService.makeRequest(items: items)
        let everything = request.messages.map(\.content).joined(separator: "\n")
        #expect(request.messages[0].content.hasPrefix(MatrixReviewService.modeMarker))
        #expect(request.messages[1].content == "1. Обновить резюме; приоритет: высокий; квадрант: Запланировать\n2. Разобрать почту; приоритет: низкий; квадрант: Убрать")
        for secret in ["Ссылка на старое", "Секретная папка", "Секретный тег", "Секретная подзадача", important.uuid.uuidString, minor.uuid.uuidString] {
            #expect(!everything.contains(secret), "\(secret)")
        }
    }

    // Без задач запрос не строится.
    @Test func запрос_безЗадач_ошибка() {
        #expect(throws: MatrixReviewError.noTasks) {
            try MatrixReviewService.makeRequest(items: [])
        }
    }

    // MARK: - Разбор ответа

    // Номера сопоставляются с задачами, пункты группируются по действиям; горизонт — только у «запланировать»;
    // неизвестные номер и действие, повторы отбрасываются; задачи без совета — пометка.
    @Test func разбор_действияГоризонтИПометки() throws {
        let tasks = [task("А"), task("Б"), task("В"), task("Г")]
        let json = """
        {"summary": "Главное — А.",
         "items": [{"id": 3, "action": "eliminate", "when": "week", "note": "Не нужно"},
                   {"id": "1", "action": "schedule", "when": "month", "note": "Важно"},
                   {"id": 2, "action": "Делегировать"},
                   {"id": 1, "action": "delegate"}, {"id": 9, "action": "schedule"}, {"id": 4, "action": "maybe"}, "мусор"]}
        """
        let review = try MatrixReviewService.parse(json, tasks: tasks)
        #expect(review.summary == "Главное — А.")
        #expect(review.items.map(\.title) == ["А", "Б", "В"])
        #expect(review.items.map(\.action) == [.schedule, .delegate, .eliminate])
        #expect(review.items.map(\.horizon) == [.month, nil, nil])
        #expect(review.items[0].taskUUID == tasks[0].uuid)
        #expect(review.notes.contains { $0.contains("неизвестным номером или действием: 3") })
        #expect(review.notes.contains { $0.contains("Без совета осталось задач: 1") })
    }

    // Не JSON или ни одного годного пункта — ошибка.
    @Test func разбор_ошибки() {
        let tasks = [task("Одна")]
        #expect(throws: MatrixReviewError.invalidJSON) { try MatrixReviewService.parse("Уберите всё", tasks: tasks) }
        #expect(throws: MatrixReviewError.emptyReview) { try MatrixReviewService.parse(#"{"items": [{"id": 1, "action": "x"}]}"#, tasks: tasks) }
        #expect(throws: MatrixReviewError.noTasks) { try MatrixReviewService.parse(#"{"items": [{"id": 1, "action": "schedule"}]}"#, tasks: []) }
    }

    // MARK: - Генератор, текст ответа, согласие

    // Генератор: один запрос; сроки, приоритеты и корзина не меняются.
    @Test func генератор_безИзмененияДанных() async throws {
        let tasks = [task("А", priority: .high), task("Б", priority: .low)]
        let provider = StubLLMProvider(.success(#"{"summary": "ok", "items": [{"id": 2, "action": "eliminate"}, {"id": 1, "action": "schedule", "when": "week"}]}"#))
        let review = try await MatrixReviewGenerator(provider: provider)
            .review(for: MatrixReviewService.selectTasks(tasks), now: Self.now, calendar: Self.calendar)
        #expect(review.items.map(\.title) == ["А", "Б"])
        #expect(provider.requests.count == 1)
        #expect(tasks.allSatisfy { $0.deadline == nil && !$0.isSoftDeleted && !$0.isCompleted })
        #expect(tasks.map(\.priority) == [.high, .low])
    }

    // Текст для «Копировать» и «Поделиться» — то же, что на карточке, по группам действий.
    @Test func текстОтвета_группыДействий() throws {
        let tasks = [task("Обновить резюме"), task("Разобрать почту"), task("Старый курс")]
        let review = try MatrixReviewService.parse("""
        {"summary": "Сосредоточьтесь на резюме.",
         "items": [{"id": 1, "action": "schedule", "when": "week", "note": "Важно для собеседований"},
                   {"id": 2, "action": "delegate", "note": ""}, {"id": 3, "action": "eliminate", "note": "Устарел"}]}
        """, tasks: tasks)

        #expect(LLMAnswerText.matrixReview(review) == """
        Разбор задач без срока
        Сосредоточьтесь на резюме.

        Запланировать
        • Обновить резюме — на этой неделе. Важно для собеседований

        Делегировать
        • Разобрать почту

        Убрать
        • Старый курс — Устарел
        """)
    }

    // Отдельное согласие: по умолчанию нет, даётся и отзывается; не связано с согласием «Плана дня».
    @Test func согласие_отдельноеОтПланаДня() {
        let name = "MatrixReviewServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        DayPlanService.giveConsent(defaults: defaults)
        #expect(MatrixReviewService.hasConsent(defaults: defaults) == false)
        MatrixReviewService.giveConsent(defaults: defaults)
        #expect(MatrixReviewService.hasConsent(defaults: defaults))
        MatrixReviewService.revokeConsent(defaults: defaults)
        #expect(MatrixReviewService.hasConsent(defaults: defaults) == false)
        #expect(DayPlanService.hasConsent(defaults: defaults))
    }
}
