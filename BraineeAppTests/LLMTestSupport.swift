//
//  LLMTestSupport.swift
//  BraineeAppTests
//
//  Общее для тестов LLM-сценариев: модель-заглушка, фиксированные «сейчас» и часовой пояс.

import Foundation
@testable import BraineeApp

enum LLMTestSupport {
    static let timeZone = TimeZone(identifier: "Europe/Moscow")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Среда, 21 октября 2026, 12:00 по Москве.
    static let now = date(2026, 10, 21, 12)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Контекст с папками «Работа», «Дом» и тегами «Звонки», «Финансы».
    static let context = TaskDraftContext(
        now: now,
        timeZone: timeZone,
        groupNames: ["Работа", "Дом"],
        tagNames: ["Звонки", "Финансы"]
    )
}

/// Модель-заглушка: запоминает запросы и возвращает заданный текст или ошибку.
final class StubLLMProvider: LLMProvider {
    var reply: Result<String, LLMError>
    private(set) var requests: [LLMRequest] = []

    init(_ reply: Result<String, LLMError>) {
        self.reply = reply
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        return LLMResponse(text: try reply.get(), model: "stub/model")
    }
}
