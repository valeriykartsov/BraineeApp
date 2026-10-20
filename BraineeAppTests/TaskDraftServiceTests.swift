//
//  TaskDraftServiceTests.swift
//  BraineeAppTests
//
//  LLM-3: «задача из текста» — состав запроса (D-26), разбор и проверка ответа модели (D-25),
//  черновик не меняет данные. Модель подменена заглушкой; время и часовой пояс фиксированы.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskDraftServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private static let timeZone = TimeZone(identifier: "Europe/Moscow")!
    /// Среда, 21 октября 2026, 12:00 по Москве.
    private static let now: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!
    }()

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private let context = TaskDraftContext(
        now: TaskDraftServiceTests.now,
        timeZone: TaskDraftServiceTests.timeZone,
        groupNames: ["Работа", "Дом"],
        tagNames: ["Звонки", "Финансы"]
    )

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Модель-заглушка: запоминает запрос и возвращает заданный текст или ошибку.
    private final class StubProvider: LLMProvider {
        var reply: Result<String, LLMError>
        var requests: [LLMRequest] = []

        init(_ reply: Result<String, LLMError>) {
            self.reply = reply
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(text: try reply.get(), model: "stub/model")
        }
    }

    // MARK: - Запрос

    // В запросе два сообщения: инструкция с датой, поясом, папками и тегами; текст пользователя — без изменений.
    @Test func запрос_инструкцияИТекстПользователя() throws {
        let request = try TaskDraftService.makeRequest(text: "  Завтра позвонить в банк  ", context: context)
        #expect(request.messages.count == 2)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[1] == LLMMessage(role: .user, content: "Завтра позвонить в банк"))

        let system = request.messages[0].content
        #expect(system.contains("2026-10-21"))
        #expect(system.contains("среда"))
        #expect(system.contains("Europe/Moscow"))
        #expect(system.contains("«Работа»") && system.contains("«Дом»"))
        #expect(system.contains("«Звонки»") && system.contains("«Финансы»"))
    }

    // Пустой и слишком длинный текст не отправляются.
    @Test func запрос_пустойИДлинныйТекстОтклоняются() {
        #expect(throws: TaskDraftError.emptyInput) {
            try TaskDraftService.makeRequest(text: "   \n", context: context)
        }
        let long = String(repeating: "а", count: TaskDraftService.maxInputLength + 1)
        #expect(throws: TaskDraftError.inputTooLong(limit: TaskDraftService.maxInputLength)) {
            try TaskDraftService.makeRequest(text: long, context: context)
        }
    }

    // D-26: из данных приложения в запрос попадают только названия папок задач и тегов —
    // не названия и описания задач, не профиль, не папки других разделов.
    @Test func составКонтекста_толькоНазванияПапокИТегов() throws {
        let modelContext = container.mainContext
        let group = TaskGroup(name: "Работа")
        let tag = TaskTag(name: "Звонки")
        modelContext.insert(group)
        modelContext.insert(tag)
        let task = TaskItem(title: "Секретная задача", sortOrder: 0)
        task.taskDetails = "Личное описание"
        modelContext.insert(task)
        task.group = group
        task.tags = [tag]
        modelContext.insert(UserProfile(displayName: "Валерий", age: 30))
        try modelContext.save()

        let groups = try modelContext.fetch(FetchDescriptor<TaskGroup>())
        let tags = try modelContext.fetch(FetchDescriptor<TaskTag>())
        let draftContext = TaskDraftContext.make(groups: groups, tags: tags, now: Self.now, timeZone: Self.timeZone)
        #expect(draftContext.groupNames == ["Работа"])
        #expect(draftContext.tagNames == ["Звонки"])

        let request = try TaskDraftService.makeRequest(text: "Купить хлеб", context: draftContext)
        let everything = request.messages.map(\.content).joined(separator: "\n")
        #expect(!everything.contains("Секретная задача"))
        #expect(!everything.contains("Личное описание"))
        #expect(!everything.contains("Валерий"))
    }

    // MARK: - Разбор ответа

    // Полный корректный ответ: дата со временем, приоритет, теги и папка из списков.
    @Test func разбор_полныйОтвет() throws {
        let json = """
        {"title":"Позвонить в банк","details":"Уточнить лимит","date":"2026-10-22","time":"10:30",
         "priority":"high","tags":["Звонки"],"group":"Работа"}
        """
        let draft = try TaskDraftService.parse(json, context: context)
        #expect(draft.title == "Позвонить в банк")
        #expect(draft.details == "Уточнить лимит")
        #expect(draft.deadline == date(2026, 10, 22, 10, 30))
        #expect(draft.hasDeadlineTime)
        #expect(draft.priority == .high)
        #expect(draft.tagNames == ["Звонки"])
        #expect(draft.groupName == "Работа")
        #expect(draft.notes.isEmpty)
    }

    // Только дата — срок на начало дня, без времени; приоритет по умолчанию — средний.
    @Test func разбор_толькоДатаИПриоритетПоУмолчанию() throws {
        let draft = try TaskDraftService.parse(#"{"title":"Отчёт","date":"2026-10-23","time":null}"#, context: context)
        #expect(draft.deadline == date(2026, 10, 23))
        #expect(draft.hasDeadlineTime == false)
        #expect(draft.priority == .medium)
        #expect(draft.tagNames.isEmpty)
        #expect(draft.groupName == nil)
    }

    // Модель обернула JSON в ```json и добавила слова — объект всё равно находится.
    @Test func разбор_jsonВMarkdownИСТекстом() throws {
        let text = """
        Вот задача:
        ```json
        {"title": "Купить молоко", "priority": "low"}
        ```
        """
        let draft = try TaskDraftService.parse(text, context: context)
        #expect(draft.title == "Купить молоко")
        #expect(draft.priority == .low)
    }

    // Не JSON или без названия — ошибка, черновика нет.
    @Test func разбор_неJSONИлиБезНазвания_ошибка() {
        #expect(throws: TaskDraftError.invalidJSON) { try TaskDraftService.parse("Не могу помочь", context: context) }
        #expect(throws: TaskDraftError.invalidJSON) { try TaskDraftService.parse("{title: без кавычек}", context: context) }
        #expect(throws: TaskDraftError.missingTitle) { try TaskDraftService.parse(#"{"title":"  "}"#, context: context) }
        #expect(throws: TaskDraftError.missingTitle) { try TaskDraftService.parse(#"{"details":"x"}"#, context: context) }
    }

    // Теги и папка — только существующие; регистр не важен, в черновик идёт точное название.
    @Test func разбор_незнакомыеТегиИПапкаОтбрасываются() throws {
        let json = #"{"title":"Задача","tags":["звонки","Спорт","ЗВОНКИ"],"group":"Отпуск"}"#
        let draft = try TaskDraftService.parse(json, context: context)
        #expect(draft.tagNames == ["Звонки"])
        #expect(draft.groupName == nil)
        #expect(draft.notes.contains { $0.contains("«Спорт»") })
        #expect(draft.notes.contains { $0.contains("«Отпуск»") })
    }

    // Один тег строкой вместо массива тоже принимается.
    @Test func разбор_тегСтрокой() throws {
        let draft = try TaskDraftService.parse(#"{"title":"Задача","tags":"Финансы"}"#, context: context)
        #expect(draft.tagNames == ["Финансы"])
    }

    // Нераспознанные дата, время и приоритет не ломают черновик — пометка в карточке.
    @Test func разбор_плохиеДатаВремяПриоритет_пометки() throws {
        let badDate = try TaskDraftService.parse(#"{"title":"А","date":"2026-02-30"}"#, context: context)
        #expect(badDate.deadline == nil)
        #expect(badDate.notes.contains { $0.contains("2026-02-30") })

        let badTime = try TaskDraftService.parse(#"{"title":"Б","date":"2026-10-22","time":"25:00"}"#, context: context)
        #expect(badTime.deadline == date(2026, 10, 22))
        #expect(badTime.hasDeadlineTime == false)
        #expect(badTime.notes.contains { $0.contains("25:00") })

        let badPriority = try TaskDraftService.parse(#"{"title":"В","priority":"urgent"}"#, context: context)
        #expect(badPriority.priority == .medium)
        #expect(!badPriority.notes.isEmpty)
    }

    // Время без даты игнорируется.
    @Test func разбор_времяБезДаты_игнорируется() throws {
        let draft = try TaskDraftService.parse(#"{"title":"Г","date":null,"time":"09:00"}"#, context: context)
        #expect(draft.deadline == nil)
        #expect(draft.hasDeadlineTime == false)
    }

    // Дата в прошлом сохраняется, но помечается для проверки.
    @Test func разбор_датаВПрошлом_пометка() throws {
        let draft = try TaskDraftService.parse(#"{"title":"Д","date":"2026-10-20"}"#, context: context)
        #expect(draft.deadline == date(2026, 10, 20))
        #expect(draft.notes.contains { $0.contains("в прошлом") })
        let today = try TaskDraftService.parse(#"{"title":"Е","date":"2026-10-21"}"#, context: context)
        #expect(today.notes.isEmpty)
    }

    // Длинные название и описание обрезаются до лимитов формы.
    @Test func разбор_длинныеПоляОбрезаются() throws {
        let longTitle = String(repeating: "т", count: 300)
        let longDetails = String(repeating: "о", count: 500)
        let draft = try TaskDraftService.parse(#"{"title":"\#(longTitle)","details":"\#(longDetails)"}"#, context: context)
        #expect(draft.title.count == TaskDraftService.maxTitleLength)
        #expect(draft.details.count == TaskInputValidation.detailsMaxLength)
        #expect(draft.notes.count == 2)
    }

    // MARK: - Генератор

    // Генератор отправляет один запрос с текстом пользователя и возвращает черновик; данные не меняются.
    @Test func генератор_черновикБезИзмененияДанных() async throws {
        let provider = StubProvider(.success(#"{"title":"Позвонить маме","date":"2026-10-22"}"#))
        let draft = try await TaskDraftGenerator(provider: provider).draft(from: "Завтра позвонить маме", context: context)
        #expect(draft.title == "Позвонить маме")
        #expect(provider.requests.count == 1)
        #expect(provider.requests.first?.messages.last?.content == "Завтра позвонить маме")
        let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.isEmpty)
    }

    // Ошибка модели передаётся как есть — для понятного сообщения в чате.
    @Test func генератор_ошибкаПровайдераПробрасывается() async {
        let provider = StubProvider(.failure(.rateLimited(retryAfterSeconds: nil)))
        do {
            _ = try await TaskDraftGenerator(provider: provider).draft(from: "Что-то", context: context)
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? LLMError == .rateLimited(retryAfterSeconds: nil))
        }
    }

    // Пустой текст не уходит в модель.
    @Test func генератор_пустойТекстНеОтправляется() async {
        let provider = StubProvider(.success("{}"))
        do {
            _ = try await TaskDraftGenerator(provider: provider).draft(from: "  ", context: context)
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? TaskDraftError == .emptyInput)
        }
        #expect(provider.requests.isEmpty)
    }
}
