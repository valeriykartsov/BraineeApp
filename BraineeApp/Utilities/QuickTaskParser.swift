//
//  QuickTaskParser.swift
//  BraineeApp
//
//  Распознавание в названии новой задачи (п. 46): дата, время, #тег, !приоритет — офлайн, без LLM.
//  «завтра в 10:30 купить хлеб #дом !высокий» → срок завтра 10:30, тег «дом», приоритет «Высокий»,
//  название «купить хлеб». Разбор, применение к полям формы и подсказки над клавиатурой — чистые функции.

import Foundation

/// Что распознано в тексте и название без распознанных меток.
struct QuickTaskParse: Equatable {
    struct Time: Equatable {
        let hour: Int
        let minute: Int
    }

    var title: String
    /// Начало дня срока.
    var day: Date?
    var time: Time?
    var priority: TaskPriority?
    /// Имена тегов из библиотеки — как они записаны там.
    var tagNames: [String] = []
}

enum QuickTaskParser {
    /// Первое совпадение каждого вида (дата, время, приоритет) применяется и убирается из названия,
    /// повторы остаются текстом. Теги — все существующие; незнакомый `#тег` остаётся текстом.
    static func parse(
        _ text: String,
        tagNames: [String],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> QuickTaskParse {
        let ns = text as NSString
        var removals: [NSRange] = []
        var result = QuickTaskParse(title: text)

        func free(_ range: NSRange) -> Bool {
            !removals.contains { NSIntersectionRange($0, range).length > 0 }
        }

        // Дата: первое по положению совпадение любого из трёх видов.
        var dateCandidates: [(range: NSRange, day: Date)] = []
        for match in matches(relativeDayPattern, in: text) {
            let word = ns.substring(with: match.range(at: 1)).lowercased()
            let offset = ["сегодня": 0, "завтра": 1, "послезавтра": 2][word] ?? 0
            if let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                dateCandidates.append((match.range, day))
            }
        }
        for match in matches(numericDatePattern, in: text) {
            let day = Int(ns.substring(with: match.range(at: 1))) ?? 0
            let month = Int(ns.substring(with: match.range(at: 2))) ?? 0
            let yearRange = match.range(at: 3)
            let year = yearRange.location == NSNotFound ? nil : Int(ns.substring(with: yearRange))
            if let date = makeDay(day: day, month: month, year: year.map { $0 < 100 ? 2000 + $0 : $0 }, now: now, calendar: calendar) {
                dateCandidates.append((match.range, date))
            }
        }
        for match in matches(textDatePattern, in: text) {
            let day = Int(ns.substring(with: match.range(at: 1))) ?? 0
            let monthName = ns.substring(with: match.range(at: 2)).lowercased()
            if let month = monthNames.firstIndex(of: monthName).map({ $0 + 1 }),
               let date = makeDay(day: day, month: month, year: nil, now: now, calendar: calendar) {
                dateCandidates.append((match.range, date))
            }
        }
        if let first = dateCandidates.min(by: { $0.range.location < $1.range.location }) {
            result.day = first.day
            removals.append(first.range)
        }

        if let match = matches(timePattern, in: text).first(where: { match in
            let hour = Int(ns.substring(with: match.range(at: 1))) ?? 99
            let minute = Int(ns.substring(with: match.range(at: 2))) ?? 99
            return hour < 24 && minute < 60 && free(match.range)
        }) {
            result.time = QuickTaskParse.Time(
                hour: Int(ns.substring(with: match.range(at: 1))) ?? 0,
                minute: Int(ns.substring(with: match.range(at: 2))) ?? 0
            )
            removals.append(match.range)
        }

        if let match = matches(priorityPattern, in: text).first(where: { free($0.range) }) {
            let word = ns.substring(with: match.range(at: 1)).lowercased()
            result.priority = TaskPriority.allCases.first { $0.title.lowercased() == word }
            removals.append(match.range)
        }

        // Теги: после `#` — самое длинное подходящее имя из библиотеки (имя может быть из нескольких слов).
        let sortedNames = tagNames.sorted { $0.utf16.count > $1.utf16.count }
        var location = 0
        while location < ns.length {
            let hash = ns.range(of: "#", options: [], range: NSRange(location: location, length: ns.length - location))
            guard hash.location != NSNotFound else { break }
            location = hash.location + 1
            guard hash.location == 0 || isSeparator(ns.character(at: hash.location - 1)) else { continue }
            for name in sortedNames where !name.isEmpty {
                let candidate = NSRange(location: hash.location + 1, length: (name as NSString).length)
                guard NSMaxRange(candidate) <= ns.length,
                      ns.substring(with: candidate).compare(name, options: .caseInsensitive) == .orderedSame,
                      NSMaxRange(candidate) == ns.length || !isWordCharacter(ns.character(at: NSMaxRange(candidate)))
                else { continue }
                let range = NSRange(location: hash.location, length: candidate.length + 1)
                guard free(range) else { break }
                if !result.tagNames.contains(name) {
                    result.tagNames.append(name)
                }
                removals.append(range)
                location = NSMaxRange(range)
                break
            }
        }

        result.title = cleaned(ns, removing: removals)
        return result
    }

    // MARK: - Шаблоны

    /// Граница слова: не буква и не цифра.
    private static let before = "(?<![\\p{L}\\p{N}])"
    private static let after = "(?![\\p{L}\\p{N}])"

    static let monthNames = [
        "января", "февраля", "марта", "апреля", "мая", "июня",
        "июля", "августа", "сентября", "октября", "ноября", "декабря"
    ]

    private static let relativeDayPattern = regex("\(before)(сегодня|завтра|послезавтра)\(after)")
    /// 25.10, 25.10.26, 25.10.2026; точка в конце предложения допустима, «25.10.2» — нет.
    private static let numericDatePattern = regex("(?<![\\p{L}\\p{N}.])(\\d{1,2})\\.(\\d{1,2})(?:\\.(\\d{4}|\\d{2}))?\(after)(?!\\.\\d)")
    private static let textDatePattern = regex("\(before)(\\d{1,2})\\s+(\(monthNames.joined(separator: "|")))\(after)")
    /// «10:30» или «в 10:30» — предлог убирается вместе со временем.
    private static let timePattern = regex("(?<![\\p{L}\\p{N}:])(?:в\\s+)?(\\d{1,2}):(\\d{2})(?![\\p{N}:])")
    private static let priorityPattern = regex("\(before)!(низкий|средний|высокий|наивысший)\(after)")

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Шаблоны постоянные: ошибка в них — ошибка программиста, её ловят тесты.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func matches(_ regex: NSRegularExpression, in text: String) -> [NSTextCheckingResult] {
        regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    /// День без года, который уже прошёл, — в следующем году; несуществующая дата (31.02) — nil.
    private static func makeDay(day: Int, month: Int, year: Int?, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        func valid(_ year: Int) -> Date? {
            let components = DateComponents(year: year, month: month, day: day)
            guard let date = calendar.date(from: components),
                  calendar.component(.day, from: date) == day,
                  calendar.component(.month, from: date) == month
            else { return nil }
            return calendar.startOfDay(for: date)
        }
        if let year { return valid(year) }
        let currentYear = calendar.component(.year, from: now)
        if let date = valid(currentYear), date >= today { return date }
        return valid(currentYear + 1)
    }

    private static func isSeparator(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private static func isWordCharacter(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    /// Убирает распознанные метки и лишние пробелы.
    private static func cleaned(_ text: NSString, removing ranges: [NSRange]) -> String {
        let result = NSMutableString(string: text)
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            result.replaceCharacters(in: range, with: " ")
        }
        return (result as String)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

// MARK: - Поля формы

/// Поля формы, которые может заполнить распознавание.
struct QuickTaskFields: Equatable {
    var hasDeadline: Bool
    var hasDeadlineTime: Bool
    var deadline: Date
    var priority: TaskPriority
    var tagNames: Set<String>
}

extension QuickTaskParser {
    /// Меняет только то, что появилось или изменилось в тексте с прошлого разбора: ручной выбор даты
    /// или приоритета в форме дальнейший ввод названия не затирает. Убранная из текста метка поле не сбрасывает.
    static func apply(
        _ parsed: QuickTaskParse,
        previous: QuickTaskParse?,
        to fields: QuickTaskFields,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> QuickTaskFields {
        var fields = fields
        if let day = parsed.day, day != previous?.day {
            let time = calendar.dateComponents([.hour, .minute], from: fields.deadline)
            fields.hasDeadline = true
            fields.deadline = fields.hasDeadlineTime
                ? calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
                : day
        }
        if let time = parsed.time, time != previous?.time {
            let base = parsed.day ?? (fields.hasDeadline ? calendar.startOfDay(for: fields.deadline) : calendar.startOfDay(for: now))
            fields.hasDeadline = true
            fields.hasDeadlineTime = true
            fields.deadline = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: base) ?? base
        }
        if let priority = parsed.priority, priority != previous?.priority {
            fields.priority = priority
        }
        fields.tagNames.formUnion(Set(parsed.tagNames).subtracting(previous?.tagNames ?? []))
        return fields
    }
}

// MARK: - Подсказки над клавиатурой

struct QuickTaskSuggestion: Equatable, Identifiable {
    /// Что подставляется вместо набранного: «#дом », «!высокий ».
    let insertion: String
    let title: String
    var id: String { insertion }
}

extension QuickTaskParser {
    /// Подсказки для последнего набранного слова: после `#` — теги по введённым буквам, после `!` — приоритеты.
    static func suggestions(for text: String, tagNames: [String]) -> [QuickTaskSuggestion] {
        guard let last = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isWhitespace }).last,
              let marker = last.first
        else { return [] }
        let typed = String(last.dropFirst()).lowercased()
        switch marker {
        case "#":
            return tagNames
                .filter { $0.lowercased().hasPrefix(typed) && $0.lowercased() != typed }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { QuickTaskSuggestion(insertion: "#\($0) ", title: "#\($0)") }
        case "!":
            return TaskPriority.allCases.reversed()
                .map { $0.title.lowercased() }
                .filter { $0.hasPrefix(typed) && $0 != typed }
                .map { QuickTaskSuggestion(insertion: "!\($0) ", title: "!\($0)") }
        default:
            return []
        }
    }

    /// Текст после нажатия на подсказку: последнее слово заменяется вариантом.
    static func applying(_ suggestion: QuickTaskSuggestion, to text: String) -> String {
        guard let index = text.lastIndex(where: { $0.isWhitespace }) else { return suggestion.insertion }
        return String(text[...index]) + suggestion.insertion
    }
}
