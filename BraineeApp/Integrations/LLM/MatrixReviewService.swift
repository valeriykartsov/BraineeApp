//
//  MatrixReviewService.swift
//  BraineeApp
//
//  Режим «Матрица» (п. 13, D-42): для активных задач без срока (до 30) модель советует
//  «запланировать» (с горизонтом), «делегировать» или «убрать». Наружу — номер, название, приоритет
//  и квадрант матрицы; без описаний, тегов, папок, подзадач, длительности и uuid.
//  Только для просмотра: сроки, приоритеты и корзина не меняются (как D-33).

import Foundation

/// Задача в запросе: всё, что о ней узнаёт модель.
struct MatrixReviewInputItem: Equatable {
    let number: Int
    let title: String
    let priority: TaskPriority
    let quadrant: EisenhowerQuadrant
}

enum MatrixReviewAction: String, CaseIterable {
    case schedule
    case delegate
    case eliminate

    var title: String {
        switch self {
        case .schedule: "Запланировать"
        case .delegate: "Делегировать"
        case .eliminate: "Убрать"
        }
    }
}

/// Когда запланировать — без конкретной даты (сроки не меняются).
enum MatrixReviewHorizon: String, CaseIterable {
    case week
    case month
    case later

    var title: String {
        switch self {
        case .week: "на этой неделе"
        case .month: "в этом месяце"
        case .later: "позже"
        }
    }
}

struct MatrixReviewItem: Equatable, Identifiable {
    var id: UUID { taskUUID }
    let taskUUID: UUID
    let title: String
    let action: MatrixReviewAction
    /// Только у «запланировать»; nil — модель не указала.
    let horizon: MatrixReviewHorizon?
    let note: String
}

struct MatrixReview: Equatable {
    var summary: String
    /// По действиям (запланировать → делегировать → убрать), внутри — в порядке ответа модели.
    var items: [MatrixReviewItem]
    var notes: [String]

    func items(for action: MatrixReviewAction) -> [MatrixReviewItem] {
        items.filter { $0.action == action }
    }
}

enum MatrixReviewError: Error, Equatable {
    case noTasks
    case invalidJSON
    case emptyReview

    var userMessage: String {
        switch self {
        case .noTasks:
            return "Задач без срока нет — разбирать нечего."
        case .invalidJSON:
            return "Модель ответила не в нужном формате. Повторите или выберите другую модель."
        case .emptyReview:
            return "Модель не разобрала задачи. Повторите."
        }
    }
}

enum MatrixReviewService {
    static let maxTasks = 30
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: разбор задач без срока."
    /// Отдельное согласие на отправку названий задач (D-42) — спрашивается один раз.
    static let consentKey = "llmMatrixConsent"

    static func hasConsent(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: consentKey)
    }

    static func giveConsent(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: consentKey)
    }

    static func revokeConsent(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: consentKey)
    }

    // MARK: - Выбор задач

    /// Не выполненные и не удалённые задачи без срока; по приоритету (выше — раньше), затем по дате создания; до 30.
    static func selectTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        let candidates = tasks.filter { !$0.isSoftDeleted && !$0.isCompleted && $0.deadline == nil }
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
        return Array(sorted.prefix(maxTasks))
    }

    static func inputItems(for tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) -> [MatrixReviewInputItem] {
        tasks.enumerated().map { index, task in
            MatrixReviewInputItem(
                number: index + 1,
                title: task.title,
                priority: task.priority,
                quadrant: EisenhowerQuadrant.classify(task, now: now, calendar: calendar)
            )
        }
    }

    // MARK: - Запрос

    static func makeRequest(items: [MatrixReviewInputItem]) throws -> LLMRequest {
        guard !items.isEmpty else { throw MatrixReviewError.noTasks }
        return LLMRequest(
            messages: [
                LLMMessage(role: .system, content: systemPrompt),
                LLMMessage(role: .user, content: tasksMessage(items))
            ],
            maxTokens: 2000,
            temperature: 0.2
        )
    }

    static let systemPrompt = """
    \(modeMarker)
    Ты помогаешь разобрать задачи без срока по матрице Эйзенхауэра.
    Тебе дают пронумерованный список: название, приоритет, квадрант матрицы.
    Ответь ТОЛЬКО JSON-объектом без пояснений и без markdown:
    {"summary": string, "items": [{"id": number, "action": "schedule" | "delegate" | "eliminate", "when": "week" | "month" | "later" | null, "note": string}]}

    Правила:
    - items — по одному пункту на каждую задачу из списка, каждую не больше одного раза.
    - action: schedule — запланировать самому, delegate — поручить другому, eliminate — убрать.
    - when — только для schedule: на этой неделе, в этом месяце или позже; для остальных null.
    - note — короткая причина по-русски (до 10 слов) или пустая строка.
    - summary — 1–2 предложения по-русски: что главное, от чего можно отказаться.
    - Учитывай приоритет и квадрант; не придумывай новых задач.
    """

    /// Список задач для модели. Только номер, название, приоритет и квадрант.
    static func tasksMessage(_ items: [MatrixReviewInputItem]) -> String {
        items.map { item in
            "\(item.number). \(item.title); приоритет: \(DayPlanService.priorityName(item.priority)); квадрант: \(item.quadrant.title)"
        }.joined(separator: "\n")
    }

    // MARK: - Разбор ответа

    /// `tasks` — те же задачи и в том же порядке, что ушли в запрос (номер = индекс + 1).
    static func parse(_ responseText: String, tasks: [TaskItem]) throws -> MatrixReview {
        guard !tasks.isEmpty else { throw MatrixReviewError.noTasks }
        guard let data = TaskDraftService.extractJSONObject(from: responseText),
              let raw = try? JSONDecoder().decode(RawReview.self, from: data) else {
            throw MatrixReviewError.invalidJSON
        }

        var items: [MatrixReviewItem] = []
        var used = Set<Int>()
        var skipped = 0
        for entry in raw.items ?? [] {
            guard let entry, let number = entry.id, (1...tasks.count).contains(number),
                  let action = entry.action.flatMap(Self.action) else {
                skipped += 1
                continue
            }
            guard used.insert(number).inserted else { continue }
            let task = tasks[number - 1]
            items.append(MatrixReviewItem(
                taskUUID: task.uuid,
                title: task.title,
                action: action,
                horizon: action == .schedule ? entry.when.flatMap(Self.horizon) : nil,
                note: String((entry.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
            ))
        }

        guard !items.isEmpty else { throw MatrixReviewError.emptyReview }
        let grouped = MatrixReviewAction.allCases.flatMap { action in items.filter { $0.action == action } }

        var notes: [String] = []
        if skipped > 0 {
            notes.append("Пропущено пунктов с неизвестным номером или действием: \(skipped).")
        }
        let missing = tasks.count - items.count
        if missing > 0 {
            notes.append("Без совета осталось задач: \(missing).")
        }
        let summary = (raw.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return MatrixReview(summary: summary, items: grouped, notes: notes)
    }

    /// Действие по-английски (как в инструкции) или по-русски.
    static func action(_ string: String) -> MatrixReviewAction? {
        let key = string.trimmingCharacters(in: .whitespaces).lowercased()
        if let action = MatrixReviewAction(rawValue: key) { return action }
        return MatrixReviewAction.allCases.first { $0.title.lowercased() == key }
    }

    static func horizon(_ string: String) -> MatrixReviewHorizon? {
        let key = string.trimmingCharacters(in: .whitespaces).lowercased()
        if let horizon = MatrixReviewHorizon(rawValue: key) { return horizon }
        return MatrixReviewHorizon.allCases.first { $0.title == key }
    }

    private struct RawReview: Decodable {
        let summary: String?
        let items: [RawEntry?]?

        enum CodingKeys: String, CodingKey { case summary, items }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            summary = try? container.decodeIfPresent(String.self, forKey: .summary)
            items = (try? container.decodeIfPresent([LenientEntry].self, forKey: .items))?.map(\.value)
        }
    }

    private struct RawEntry: Decodable {
        let id: Int?
        let action: String?
        let when: String?
        let note: String?

        enum CodingKeys: String, CodingKey { case id, action, when, note }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Номер может прийти числом или строкой.
            if let number = try? container.decodeIfPresent(Int.self, forKey: .id) {
                id = number
            } else if let text = try? container.decodeIfPresent(String.self, forKey: .id) {
                id = Int(text.trimmingCharacters(in: .whitespaces))
            } else {
                id = nil
            }
            action = try? container.decodeIfPresent(String.self, forKey: .action)
            when = try? container.decodeIfPresent(String.self, forKey: .when)
            note = try? container.decodeIfPresent(String.self, forKey: .note)
        }
    }

    private struct LenientEntry: Decodable {
        let value: RawEntry?
        init(from decoder: Decoder) throws {
            value = try? RawEntry(from: decoder)
        }
    }
}

/// Запрос «Матрицы» к модели и разбор ответа.
struct MatrixReviewGenerator {
    let provider: LLMProvider

    func review(for tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) async throws -> MatrixReview {
        let items = MatrixReviewService.inputItems(for: tasks, now: now, calendar: calendar)
        let request = try MatrixReviewService.makeRequest(items: items)
        let response = try await provider.complete(request)
        return try MatrixReviewService.parse(response.text, tasks: tasks)
    }
}
