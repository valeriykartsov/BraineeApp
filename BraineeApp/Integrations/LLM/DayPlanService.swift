//
//  DayPlanService.swift
//  BraineeApp
//
//  «План дня» (LLM-4, D-32…D-34). Наружу впервые уходят названия задач: только задачи на сегодня
//  и просроченные (до 30) — номер, название, приоритет, время срока, признак «просрочена».
//  Без описаний, тегов, папок и uuid: модель видит номера 1…N, код сам сопоставляет их с задачами.
//  План только для просмотра — сроки и порядок задач не меняются (D-33).
//  Встречи из Календаря (D-44) — только обезличенные занятые промежутки сегодня («10:00–11:00», «весь день»),
//  без названий, календарей, мест и участников; не больше 20; только при включённых «Встречах из Календаря».

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
    static let maxBusySlots = 20
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: план дня."
    /// Согласие на отправку названий задач и занятого времени (D-32, D-44) — спрашивается один раз.
    /// Новый ключ: согласие по старому составу данных (`llmDayPlanConsent`) для нового не действует.
    static let consentKey = "llmDayPlanConsentV2"
    static let legacyConsentKey = "llmDayPlanConsent"

    static func hasConsent(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: consentKey)
    }

    static func giveConsent(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: consentKey)
        defaults.removeObject(forKey: legacyConsentKey)
    }

    static func revokeConsent(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: consentKey)
        defaults.removeObject(forKey: legacyConsentKey)
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

    // MARK: - Занятое время (D-44)

    /// Занятые промежутки сегодня из встреч дня: только время, без данных о встречах.
    /// «весь день» — если есть событие на весь день; остальные — «ЧЧ:ММ–ЧЧ:ММ» по времени,
    /// пересекающиеся и смежные склеены, уже закончившиеся отброшены; не больше 20.
    static func busySlots(from meetings: [DayMeeting], now: Date = .now, calendar: Calendar = .current) -> [String] {
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var slots: [String] = []
        if meetings.contains(where: { $0.timing == .allDay }) {
            slots.append("весь день")
        }

        let ranges = meetings.compactMap { item -> (start: Date, end: Date)? in
            guard item.timing != .allDay else { return nil }
            let start = max(item.meeting.start, dayStart)
            let end = min(item.meeting.end, dayEnd)
            guard end > now, end > start else { return nil }
            return (start, end)
        }.sorted { $0.start < $1.start }

        var merged: [(start: Date, end: Date)] = []
        for range in ranges {
            if let last = merged.last, range.start <= last.end {
                merged[merged.count - 1].end = max(last.end, range.end)
            } else {
                merged.append(range)
            }
        }

        slots += merged.map { range in
            let end = range.end >= dayEnd ? "24:00" : CalendarMeetingRules.timeText(range.end, calendar: calendar)
            return "\(CalendarMeetingRules.timeText(range.start, calendar: calendar))–\(end)"
        }
        return Array(slots.prefix(maxBusySlots))
    }

    // MARK: - Запрос

    /// `busySlots` — из `busySlots(from:)`; пусто — о занятом времени модель не узнаёт.
    static func makeRequest(
        items: [DayPlanInputItem],
        busySlots: [String] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> LLMRequest {
        guard !items.isEmpty else { throw DayPlanError.noTasks }
        var userMessage = tasksMessage(items)
        if !busySlots.isEmpty {
            userMessage += "\n\n" + busyMessage(busySlots)
        }
        return LLMRequest(
            messages: [
                LLMMessage(role: .system, content: systemPrompt(now: now, calendar: calendar)),
                LLMMessage(role: .user, content: userMessage)
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
        - Если после списка дано занятое время — не ставь задачи на эти промежутки; «весь день» — на день есть событие, оставь задачи без жёсткого времени или с запасом.
        """
    }

    /// Занятое время для модели: только промежутки, без названий и других данных встреч.
    static func busyMessage(_ slots: [String]) -> String {
        (["Занятое время сегодня (встречи):"] + slots).joined(separator: "\n")
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

    func plan(
        for tasks: [TaskItem],
        busySlots: [String] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws -> DayPlan {
        let items = DayPlanService.inputItems(for: tasks, now: now, calendar: calendar)
        let request = try DayPlanService.makeRequest(items: items, busySlots: busySlots, now: now, calendar: calendar)
        let response = try await provider.complete(request)
        return try DayPlanService.parse(response.text, tasks: tasks)
    }
}
