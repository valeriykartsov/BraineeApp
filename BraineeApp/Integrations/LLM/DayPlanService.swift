//
//  DayPlanService.swift
//  BraineeApp
//
//  «План дня» (LLM-4, D-32…D-34). Наружу впервые уходят названия задач: только задачи на сегодня
//  и просроченные (до 30) — номер, название, приоритет, время срока, признак «просрочена».
//  Без описаний, тегов, папок и uuid: модель видит номера 1…N, код сам сопоставляет их с задачами.
//  План только для просмотра — сроки и порядок задач не меняются (D-33). Календарь не используется (D-34).

import Foundation

/// Задача в запросе: всё, что о ней узнаёт модель.
struct DayPlanInputItem: Equatable {
    let number: Int
    let title: String
    let priority: TaskPriority
    /// «HH:mm», если у срока есть время и он сегодня.
    let time: String?
    let isOverdue: Bool
}

struct DayPlanItem: Equatable, Identifiable {
    var id: UUID { taskUUID }
    let taskUUID: UUID
    let title: String
    let priority: TaskPriority
    /// Время, которое предложила модель («HH:mm»), если оно разобралось.
    let suggestedTime: String?
    let note: String
}

struct DayPlan: Equatable {
    var summary: String
    var items: [DayPlanItem]
    var notes: [String]
}

enum DayPlanError: Error, Equatable {
    case noTasks
    case invalidJSON
    case emptyPlan

    var userMessage: String {
        switch self {
        case .noTasks:
            return "На сегодня нет задач и просроченных — планировать нечего."
        case .invalidJSON:
            return "Модель ответила не в нужном формате. Повторите или выберите другую модель."
        case .emptyPlan:
            return "Модель не составила план. Повторите."
        }
    }
}

enum DayPlanService {
    static let maxTasks = 30
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: план дня."
    /// Согласие на отправку названий задач (D-32) — спрашивается один раз.
    static let consentKey = "llmDayPlanConsent"

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

    /// Не выполненные и не удалённые задачи со сроком сегодня или просроченные.
    /// Порядок: просроченные, затем по приоритету (выше — раньше), затем по сроку; не больше 30.
    static func selectTasks(_ tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) -> [TaskItem] {
        let candidates = tasks.filter { task in
            !task.isSoftDeleted && !task.isCompleted
                && (task.isDue(on: now, calendar: calendar) || task.isOverdue(at: now, calendar: calendar))
        }
        let sorted = candidates.sorted { lhs, rhs in
            let lhsOverdue = lhs.isOverdue(at: now, calendar: calendar)
            let rhsOverdue = rhs.isOverdue(at: now, calendar: calendar)
            if lhsOverdue != rhsOverdue { return lhsOverdue }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return (lhs.deadline ?? .distantFuture) < (rhs.deadline ?? .distantFuture)
        }
        return Array(sorted.prefix(maxTasks))
    }

    static func inputItems(for tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) -> [DayPlanInputItem] {
        tasks.enumerated().map { index, task in
            var time: String?
            if task.hasDeadlineTime, let deadline = task.deadline, calendar.isDate(deadline, inSameDayAs: now) {
                let c = calendar.dateComponents([.hour, .minute], from: deadline)
                time = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
            }
            return DayPlanInputItem(
                number: index + 1,
                title: task.title,
                priority: task.priority,
                time: time,
                isOverdue: task.isOverdue(at: now, calendar: calendar)
            )
        }
    }

    // MARK: - Запрос

    static func makeRequest(items: [DayPlanInputItem], now: Date = .now, calendar: Calendar = .current) throws -> LLMRequest {
        guard !items.isEmpty else { throw DayPlanError.noTasks }
        return LLMRequest(
            messages: [
                LLMMessage(role: .system, content: systemPrompt(now: now, calendar: calendar)),
                LLMMessage(role: .user, content: tasksMessage(items))
            ],
            maxTokens: 2000,
            temperature: 0.2
        )
    }

    static func systemPrompt(now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: now)
        let time = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        return """
        \(modeMarker)
        Ты помогаешь составить реалистичный план на остаток сегодняшнего дня. Сейчас \(time).
        Тебе дают пронумерованный список задач: название, приоритет, время срока (если есть), просрочена ли.
        Ответь ТОЛЬКО JSON-объектом без пояснений и без markdown:
        {"summary": string, "plan": [{"id": number, "time": "HH:mm" | null, "note": string}]}

        Правила:
        - plan — номера задач из списка в рекомендуемом порядке; каждую задачу не больше одного раза.
        - time — предлагаемое время начала, не раньше \(time); задачи с временем срока ставь до него; null, если время не важно.
        - note — короткий совет к задаче (до 10 слов) или пустая строка.
        - summary — 1–2 предложения о дне по-русски: что главное, что можно перенести.
        - Учитывай приоритет и просрочку; не придумывай новых задач.
        """
    }

    /// Список задач для модели. Только номер, название, приоритет, время срока и просрочка.
    static func tasksMessage(_ items: [DayPlanInputItem]) -> String {
        items.map { item in
            var parts = ["\(item.number). \(item.title)", "приоритет: \(priorityName(item.priority))"]
            if let time = item.time { parts.append("срок: \(time)") }
            if item.isOverdue { parts.append("просрочена") }
            return parts.joined(separator: "; ")
        }.joined(separator: "\n")
    }

    /// Приоритет словом для запросов «Плана дня» и «Матрицы».
    static func priorityName(_ priority: TaskPriority) -> String {
        switch priority {
        case .low: "низкий"
        case .medium: "средний"
        case .high: "высокий"
        case .highest: "наивысший"
        }
    }

    // MARK: - Разбор ответа

    /// `tasks` — те же задачи и в том же порядке, что ушли в запрос (номер = индекс + 1).
    static func parse(_ responseText: String, tasks: [TaskItem]) throws -> DayPlan {
        guard !tasks.isEmpty else { throw DayPlanError.noTasks }
        guard let data = TaskDraftService.extractJSONObject(from: responseText),
              let raw = try? JSONDecoder().decode(RawPlan.self, from: data) else {
            throw DayPlanError.invalidJSON
        }

        var items: [DayPlanItem] = []
        var notes: [String] = []
        var used = Set<Int>()
        var unknown = 0
        for entry in raw.plan ?? [] {
            guard let number = entry?.id, (1...tasks.count).contains(number) else {
                unknown += 1
                continue
            }
            guard used.insert(number).inserted else { continue }
            let task = tasks[number - 1]
            items.append(DayPlanItem(
                taskUUID: task.uuid,
                title: task.title,
                priority: task.priority,
                suggestedTime: entry?.time.flatMap(validTime),
                note: String((entry?.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
            ))
        }

        guard !items.isEmpty else { throw DayPlanError.emptyPlan }
        if unknown > 0 {
            notes.append("Пропущено пунктов с неизвестным номером: \(unknown).")
        }
        let missing = tasks.count - items.count
        if missing > 0 {
            notes.append("Не вошли в план задач: \(missing) — их можно сделать позже или перенести.")
        }
        let summary = (raw.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return DayPlan(summary: summary, items: items, notes: notes)
    }

    /// «H:mm» или «HH:mm» → «HH:mm»; иначе `nil`.
    static func validTime(_ string: String) -> String? {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return String(format: "%02d:%02d", parts[0], parts[1])
    }

    private struct RawPlan: Decodable {
        let summary: String?
        let plan: [RawEntry?]?

        enum CodingKeys: String, CodingKey { case summary, plan }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            summary = try? container.decodeIfPresent(String.self, forKey: .summary)
            plan = (try? container.decodeIfPresent([LenientEntry].self, forKey: .plan))?.map(\.value)
        }
    }

    private struct RawEntry: Decodable {
        let id: Int?
        let time: String?
        let note: String?

        enum CodingKeys: String, CodingKey { case id, time, note }

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
            time = try? container.decodeIfPresent(String.self, forKey: .time)
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

/// Запрос «Плана дня» к модели и разбор ответа.
struct DayPlanGenerator {
    let provider: LLMProvider

    func plan(for tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) async throws -> DayPlan {
        let items = DayPlanService.inputItems(for: tasks, now: now, calendar: calendar)
        let request = try DayPlanService.makeRequest(items: items, now: now, calendar: calendar)
        let response = try await provider.complete(request)
        return try DayPlanService.parse(response.text, tasks: tasks)
    }
}
