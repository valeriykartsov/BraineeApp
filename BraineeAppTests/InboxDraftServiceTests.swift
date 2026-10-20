//
//  InboxDraftServiceTests.swift
//  BraineeAppTests
//
//  LLM-6 «Разбор»: длинный текст → несколько черновиков (D-30). Состав запроса как в D-26,
//  битые элементы отбрасываются с пометкой, лимит 10 черновиков. Модель подменена заглушкой.

import Foundation
import Testing
@testable import BraineeApp

struct InboxDraftServiceTests {
    private let context = LLMTestSupport.context

    // MARK: - Запрос

    // Инструкция: метка режима, дата, пояс, папки и теги, формат массива; текст пользователя — без изменений.
    @Test func запрос_инструкцияМассиваИТекст() throws {
        let request = try InboxDraftService.makeRequest(text: "  купить хлеб\nпозвонить маме  ", context: context)
        #expect(request.messages.count == 2)
        #expect(request.messages[1] == LLMMessage(role: .user, content: "купить хлеб\nпозвонить маме"))

        let system = request.messages[0].content
        #expect(system.hasPrefix(InboxDraftService.modeMarker))
        #expect(system.contains("2026-10-21"))
        #expect(system.contains("Europe/Moscow"))
        #expect(system.contains("«Работа»") && system.contains("«Звонки»"))
        #expect(system.contains(#"{"tasks": ["#))
        #expect(system.contains("не больше \(InboxDraftService.maxDrafts)"))
    }

    // Лимит текста для «Разбора» больше, чем для «Задачи», но тоже есть.
    @Test func запрос_лимитыТекста() throws {
        let fits = String(repeating: "а", count: InboxDraftService.maxInputLength)
        #expect(throws: Never.self) { try InboxDraftService.makeRequest(text: fits, context: context) }
        #expect(throws: TaskDraftError.inputTooLong(limit: InboxDraftService.maxInputLength)) {
            try InboxDraftService.makeRequest(text: fits + "а", context: context)
        }
        #expect(throws: TaskDraftError.emptyInput) {
            try InboxDraftService.makeRequest(text: " ", context: context)
        }
    }

    // MARK: - Разбор ответа

    // Несколько задач: каждая проверяется как в «Задаче» (дата, теги, папка).
    @Test func разбор_несколькоЗадач() throws {
        let json = """
        {"tasks": [
          {"title": "Позвонить в банк", "date": "2026-10-22", "time": "10:00", "priority": "high", "tags": ["звонки"]},
          {"title": "Купить продукты", "details": "Молоко", "group": "Дом"}
        ]}
        """
        let result = try InboxDraftService.parse(json, context: context)
        #expect(result.drafts.map(\.title) == ["Позвонить в банк", "Купить продукты"])
        #expect(result.drafts[0].deadline == LLMTestSupport.date(2026, 10, 22, 10))
        #expect(result.drafts[0].tagNames == ["Звонки"])
        #expect(result.drafts[1].groupName == "Дом")
        #expect(result.notes.isEmpty)
    }

    // Элемент без названия или не того типа отбрасывается, остальные остаются.
    @Test func разбор_битыеЭлементыОтбрасываются() throws {
        let json = #"{"tasks": [{"title": "Первая"}, {"title": ""}, 42, {"details": "без названия"}, {"title": "Вторая"}]}"#
        let result = try InboxDraftService.parse(json, context: context)
        #expect(result.drafts.map(\.title) == ["Первая", "Вторая"])
        #expect(result.notes.contains { $0.contains("Не разобрано элементов: 3") })
    }

    // Массив верхнего уровня и обёртка ```json тоже принимаются.
    @Test func разбор_массивВерхнегоУровняВMarkdown() throws {
        let text = """
        Вот задачи:
        ```json
        [{"title": "Первая"}, {"title": "Вторая", "priority": "low"}]
        ```
        """
        let result = try InboxDraftService.parse(text, context: context)
        #expect(result.drafts.map(\.title) == ["Первая", "Вторая"])
        #expect(result.drafts[1].priority == .low)
    }

    // Повторы по названию (без учёта регистра) убираются.
    @Test func разбор_повторыУбираются() throws {
        let json = #"{"tasks": [{"title": "Купить хлеб"}, {"title": "купить хлеб"}, {"title": "Позвонить"}]}"#
        let result = try InboxDraftService.parse(json, context: context)
        #expect(result.drafts.map(\.title) == ["Купить хлеб", "Позвонить"])
        #expect(result.notes.contains { $0.contains("Повтор") })
    }

    // Больше 10 задач — показываются первые 10 с пометкой.
    @Test func разбор_большеЛимита_первые10() throws {
        let items = (1...13).map { #"{"title": "Задача \#($0)"}"# }.joined(separator: ",")
        let result = try InboxDraftService.parse(#"{"tasks": [\#(items)]}"#, context: context)
        #expect(result.drafts.count == InboxDraftService.maxDrafts)
        #expect(result.drafts.last?.title == "Задача 10")
        #expect(result.notes.contains { $0.contains("первые 10 задач из 13") })
    }

    // Не JSON или ни одной годной задачи — ошибка, черновиков нет.
    @Test func разбор_нетЗадач_ошибка() {
        #expect(throws: TaskDraftError.invalidJSON) { try InboxDraftService.parse("Ничего не нашёл", context: context) }
        #expect(throws: TaskDraftError.missingTitle) { try InboxDraftService.parse(#"{"tasks": []}"#, context: context) }
        #expect(throws: TaskDraftError.missingTitle) {
            try InboxDraftService.parse(#"{"tasks": [{"title": " "}]}"#, context: context)
        }
    }

    // MARK: - Генератор

    // Один запрос с текстом пользователя; результат — проверенные черновики.
    @Test func генератор_одинЗапросНесколькоЧерновиков() async throws {
        let provider = StubLLMProvider(.success(#"{"tasks": [{"title": "А"}, {"title": "Б"}]}"#))
        let result = try await InboxDraftGenerator(provider: provider).drafts(from: "а и б", context: context)
        #expect(result.drafts.map(\.title) == ["А", "Б"])
        #expect(provider.requests.count == 1)
        #expect(provider.requests.first?.messages.last?.content == "а и б")
    }

    // Ошибка модели передаётся как есть.
    @Test func генератор_ошибкаПровайдераПробрасывается() async {
        let provider = StubLLMProvider(.failure(.offline))
        do {
            _ = try await InboxDraftGenerator(provider: provider).drafts(from: "что-то", context: context)
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? LLMError == .offline)
        }
    }
}
