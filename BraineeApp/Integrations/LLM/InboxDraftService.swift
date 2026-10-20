//
//  InboxDraftService.swift
//  BraineeApp
//
//  «Разбор» (LLM-6, D-30): длинный текст «всё, что в голове» → до 10 черновиков задач.
//  Наружу — то же, что в «Задаче» (D-26). Каждый черновик проверяется как в LLM-3 и
//  сохраняется отдельно через форму; битые элементы отбрасываются с пометкой, а не ломают ответ.

import Foundation

/// Результат разбора: проверенные черновики и пометки о том, что отброшено.
struct InboxDraftResult: Equatable {
    var drafts: [TaskDraft]
    var notes: [String]
}

enum InboxDraftService {
    static let maxInputLength = 3000
    static let maxDrafts = 10
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: разбор списка."

    // MARK: - Запрос

    static func makeRequest(text: String, context: TaskDraftContext) throws -> LLMRequest {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw TaskDraftError.emptyInput }
        guard input.count <= maxInputLength else { throw TaskDraftError.inputTooLong(limit: maxInputLength) }
        return LLMRequest(
            messages: [
                LLMMessage(role: .system, content: systemPrompt(context: context)),
                LLMMessage(role: .user, content: input)
            ],
            maxTokens: 2000,
            temperature: 0
        )
    }

    static func systemPrompt(context: TaskDraftContext) -> String {
        """
        \(modeMarker)
        Ты помогаешь разобрать текст пользователя на отдельные задачи для списка дел.
        \(TaskDraftService.contextLines(context))

        Ответь ТОЛЬКО JSON-объектом без пояснений и без markdown:
        {"tasks": [\(TaskDraftService.draftSchema), ...]}

        Правила:
        - Каждое отдельное дело — отдельная задача; не больше \(maxDrafts) задач, самые важные первыми.
        - Не дублируй одно и то же дело; мысли без конкретного действия пропускай.
        \(TaskDraftService.fieldRules)
        """
    }

    // MARK: - Разбор ответа

    static func parse(_ responseText: String, context: TaskDraftContext) throws -> InboxDraftResult {
        guard let items = extractItems(from: responseText) else { throw TaskDraftError.invalidJSON }

        var drafts: [TaskDraft] = []
        var notes: [String] = []
        var skipped = 0
        for item in items {
            guard let raw = item, let draft = try? TaskDraftService.validate(raw, context: context) else {
                skipped += 1
                continue
            }
            // Одинаковые названия в одном ответе — одна задача.
            if drafts.contains(where: { $0.title.caseInsensitiveCompare(draft.title) == .orderedSame }) {
                notes.append("Повтор «\(draft.title)» убран.")
                continue
            }
            drafts.append(draft)
        }

        if skipped > 0 {
            notes.append("Не разобрано элементов: \(skipped) — без названия или в неверном формате.")
        }
        if drafts.count > maxDrafts {
            notes.append("Показаны первые \(maxDrafts) задач из \(drafts.count).")
            drafts = Array(drafts.prefix(maxDrafts))
        }
        guard !drafts.isEmpty else { throw TaskDraftError.missingTitle }
        return InboxDraftResult(drafts: drafts, notes: notes)
    }

    /// Элементы массива `tasks` (или массива верхнего уровня). Элемент, который не разобрался, — `nil`.
    static func extractItems(from text: String) -> [TaskDraftService.RawTaskDraft?]? {
        let decoder = JSONDecoder()
        if let data = TaskDraftService.extractJSONObject(from: text),
           let envelope = try? decoder.decode(Envelope.self, from: data) {
            return envelope.tasks.map(\.value)
        }
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end,
           let list = try? decoder.decode([LenientItem].self, from: Data(text[start...end].utf8)) {
            return list.map(\.value)
        }
        return nil
    }

    private struct Envelope: Decodable {
        let tasks: [LenientItem]
    }

    /// Элемент массива, который не валит весь массив, если сам не разобрался.
    private struct LenientItem: Decodable {
        let value: TaskDraftService.RawTaskDraft?

        init(from decoder: Decoder) throws {
            value = try? TaskDraftService.RawTaskDraft(from: decoder)
        }
    }
}

/// Запрос «Разбора» к модели и разбор ответа.
struct InboxDraftGenerator {
    let provider: LLMProvider

    func drafts(from text: String, context: TaskDraftContext) async throws -> InboxDraftResult {
        let request = try InboxDraftService.makeRequest(text: text, context: context)
        let response = try await provider.complete(request)
        return try InboxDraftService.parse(response.text, context: context)
    }
}
