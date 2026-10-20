//
//  TaskDraftService.swift
//  BraineeApp
//
//  «Задача из текста» (LLM-3, D-25, D-26). Наружу уходят только: текст пользователя,
//  текущая дата, часовой пояс, названия папок и тегов. Каждый запрос — отдельно, без истории.
//  Ответ модели всегда проверяется кодом и превращается в черновик; данные не меняются,
//  пока пользователь не сохранит черновик в обычной форме задачи.

import Foundation

/// Минимальный контекст для модели (D-26).
struct TaskDraftContext: Equatable {
    var now: Date
    var timeZone: TimeZone
    var groupNames: [String]
    var tagNames: [String]

    /// Из моделей берутся только названия папок задач и тегов — ничего о самих задачах и профиле.
    static func make(groups: [TaskGroup], tags: [TaskTag], now: Date = .now, timeZone: TimeZone = .current) -> TaskDraftContext {
        TaskDraftContext(
            now: now,
            timeZone: timeZone,
            groupNames: groups.filter { $0.category == .tasks }.map(\.name),
            tagNames: tags.map(\.name)
        )
    }
}

/// Проверенный черновик задачи. Теги и папка — только из существующих (по имени, без учёта регистра).
struct TaskDraft: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var details: String
    /// Начало дня (без времени) или точный момент (с временем) — как `TaskItem.deadline`.
    var deadline: Date?
    var hasDeadlineTime: Bool
    var priority: TaskPriority
    var tagNames: [String]
    var groupName: String?
    /// Что пришлось поправить или отбросить — показывается в карточке черновика.
    var notes: [String]

    static func == (lhs: TaskDraft, rhs: TaskDraft) -> Bool {
        lhs.title == rhs.title && lhs.details == rhs.details && lhs.deadline == rhs.deadline
            && lhs.hasDeadlineTime == rhs.hasDeadlineTime && lhs.priority == rhs.priority
            && lhs.tagNames == rhs.tagNames && lhs.groupName == rhs.groupName && lhs.notes == rhs.notes
    }
}

enum TaskDraftError: Error, Equatable {
    case emptyInput
    case inputTooLong(limit: Int)
    case invalidJSON
    case missingTitle

    var userMessage: String {
        switch self {
        case .emptyInput:
            return "Опишите задачу словами."
        case .inputTooLong(let limit):
            return "Текст слишком длинный: не больше \(limit) символов."
        case .invalidJSON:
            return "Модель ответила не в нужном формате. Повторите или выберите другую модель."
        case .missingTitle:
            return "Модель не смогла выделить название задачи. Уточните текст."
        }
    }
}

enum TaskDraftService {
    static let maxInputLength = 1000
    /// Максимум символов в названии черновика (длиннее — обрезается с пометкой).
    static let maxTitleLength = 200

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
            maxTokens: 600,
            temperature: 0
        )
    }

    static func systemPrompt(context: TaskDraftContext) -> String {
        """
        Ты помогаешь превратить фразу пользователя в одну задачу для списка дел.
        \(contextLines(context))

        Ответь ТОЛЬКО JSON-объектом без пояснений и без markdown:
        \(draftSchema)

        Правила:
        \(fieldRules)
        """
    }

    /// Дата, часовой пояс, папки и теги — общие для всех режимов с черновиками (D-26).
    static func contextLines(_ context: TaskDraftContext) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.timeZone
        let today = dayString(context.now, calendar: calendar)
        let weekday = weekdayName(context.now, calendar: calendar)
        let groups = context.groupNames.isEmpty ? "(нет)" : context.groupNames.map { "«\($0)»" }.joined(separator: ", ")
        let tags = context.tagNames.isEmpty ? "(нет)" : context.tagNames.map { "«\($0)»" }.joined(separator: ", ")
        return """
        Сегодня \(today) (\(weekday)), часовой пояс \(context.timeZone.identifier).
        Папки пользователя: \(groups).
        Теги пользователя: \(tags).
        """
    }

    /// JSON одного черновика.
    static let draftSchema = """
    {"title": string, "details": string, "date": "YYYY-MM-DD" | null, "time": "HH:mm" | null, \
    "priority": "low" | "medium" | "high" | "highest", "tags": [string], "group": string | null}
    """

    /// Правила заполнения полей черновика.
    static let fieldRules = """
    - title — коротко, по-русски, с заглавной буквы, без даты и времени.
    - details — подробности из фразы или пустая строка.
    - date — только если срок назван или однозначно следует из фразы («завтра», «в пятницу»); иначе null.
    - time — только если назван час; без date время не указывай.
    - priority — "medium", если важность не указана.
    - tags и group — только из списков выше, точными названиями; не придумывай новых.
    """

    // MARK: - Разбор ответа

    static func parse(_ responseText: String, context: TaskDraftContext) throws -> TaskDraft {
        guard let data = extractJSONObject(from: responseText),
              let raw = try? JSONDecoder().decode(RawTaskDraft.self, from: data) else {
            throw TaskDraftError.invalidJSON
        }
        return try validate(raw, context: context)
    }

    /// Проверка одного черновика из ответа модели (общая для «Задачи» и «Разбора»).
    static func validate(_ raw: RawTaskDraft, context: TaskDraftContext) throws -> TaskDraft {
        var notes: [String] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.timeZone

        var title = (raw.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TaskDraftError.missingTitle }
        if title.count > maxTitleLength {
            title = String(title.prefix(maxTitleLength))
            notes.append("Название сокращено до \(maxTitleLength) символов.")
        }

        let rawDetails = (raw.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let details = TaskInputValidation.clampedDetails(rawDetails)
        if details.count < rawDetails.count {
            notes.append("Описание сокращено до \(TaskInputValidation.detailsMaxLength) символов.")
        }

        var deadline: Date?
        var hasDeadlineTime = false
        if let dateString = raw.date?.trimmingCharacters(in: .whitespaces), !dateString.isEmpty {
            if let day = parseDay(dateString, calendar: calendar) {
                deadline = day
                if let timeString = raw.time?.trimmingCharacters(in: .whitespaces), !timeString.isEmpty {
                    if let withTime = applyTime(timeString, to: day, calendar: calendar) {
                        deadline = withTime
                        hasDeadlineTime = true
                    } else {
                        notes.append("Время «\(timeString)» не распознано — оставлена только дата.")
                    }
                }
                if day < calendar.startOfDay(for: context.now) {
                    notes.append("Дата в прошлом — проверьте её.")
                }
            } else {
                notes.append("Дата «\(dateString)» не распознана — срок не указан.")
            }
        }

        let priority: TaskPriority
        switch raw.priority?.lowercased() {
        case "low": priority = .low
        case "high": priority = .high
        case "highest": priority = .highest
        case "medium", nil: priority = .medium
        default:
            priority = .medium
            notes.append("Приоритет не распознан — выбран «Средний».")
        }

        var tagNames: [String] = []
        var unknownTags: [String] = []
        for name in raw.tags ?? [] {
            if let match = existingName(name, in: context.tagNames) {
                if !tagNames.contains(match) { tagNames.append(match) }
            } else if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                unknownTags.append(name)
            }
        }
        if !unknownTags.isEmpty {
            notes.append("Теги не найдены и не добавлены: \(unknownTags.map { "«\($0)»" }.joined(separator: ", ")).")
        }

        var groupName: String?
        if let rawGroup = raw.group?.trimmingCharacters(in: .whitespaces), !rawGroup.isEmpty {
            if let match = existingName(rawGroup, in: context.groupNames) {
                groupName = match
            } else {
                notes.append("Папка «\(rawGroup)» не найдена — задача будет без папки.")
            }
        }

        return TaskDraft(
            title: title,
            details: details,
            deadline: deadline,
            hasDeadlineTime: hasDeadlineTime,
            priority: priority,
            tagNames: tagNames,
            groupName: groupName,
            notes: notes
        )
    }

    /// Первый JSON-объект в тексте: модель может обернуть его в ```json … ``` или добавить слова.
    static func extractJSONObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        return Data(text[start...end].utf8)
    }

    // MARK: - Помощники

    /// Черновик в том виде, как его прислала модель: все поля необязательны, лишние игнорируются.
    struct RawTaskDraft: Decodable {
        let title: String?
        let details: String?
        let date: String?
        let time: String?
        let priority: String?
        let tags: [String]?
        let group: String?

        enum CodingKeys: String, CodingKey {
            case title, details, date, time, priority, tags, group
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            details = try? container.decodeIfPresent(String.self, forKey: .details)
            date = try? container.decodeIfPresent(String.self, forKey: .date)
            time = try? container.decodeIfPresent(String.self, forKey: .time)
            priority = try? container.decodeIfPresent(String.self, forKey: .priority)
            // Один тег строкой вместо массива — тоже принимаем.
            if let list = try? container.decodeIfPresent([String].self, forKey: .tags) {
                tags = list
            } else if let single = try? container.decodeIfPresent(String.self, forKey: .tags) {
                tags = [single]
            } else {
                tags = nil
            }
            group = try? container.decodeIfPresent(String.self, forKey: .group)
        }
    }

    private static func existingName(_ name: String, in names: [String]) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    static func parseDay(_ string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
              calendar.component(.month, from: date) == parts[1],
              calendar.component(.day, from: date) == parts[2] else { return nil }
        return calendar.startOfDay(for: date)
    }

    static func applyTime(_ string: String, to day: Date, calendar: Calendar) -> Date? {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    private static func dayString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        let names = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        return names[(calendar.component(.weekday, from: date) - 1) % 7]
    }
}

/// Запрос к модели и разбор ответа. Провайдер подменяется в тестах.
struct TaskDraftGenerator {
    let provider: LLMProvider

    func draft(from text: String, context: TaskDraftContext) async throws -> TaskDraft {
        let request = try TaskDraftService.makeRequest(text: text, context: context)
        let response = try await provider.complete(request)
        return try TaskDraftService.parse(response.text, context: context)
    }
}
