//
//  ReflectionService.swift
//  BraineeApp
//
//  «Итоги» (LLM-5, D-31): цифры за сегодня или последние 7 дней считает код; модель получает
//  только числа (без названий задач и привычек) и формулирует короткий текст. Данные не меняются.
//  Встречи из Календаря (D-44) — тоже только числа: сколько встреч и сколько времени в них.

import Foundation

enum ReflectionPeriod: String, CaseIterable, Identifiable, Codable {
    case today
    /// Последние 7 дней до момента запроса (п. 49, 2026-10-26; раньше — текущая неделя). rawValue прежний.
    case last7Days = "week"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Сегодня"
        case .last7Days: "7 дней"
        }
    }

    /// Заголовок карточки и текста «Копировать».
    var reportTitle: String {
        switch self {
        case .today: "Итоги дня"
        case .last7Days: "Итоги за 7 дней"
        }
    }

    /// Начало периода: начало сегодняшнего дня или ровно 7 суток до `now`. Конец — `now`.
    func start(now: Date, calendar: Calendar) -> Date {
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }

    /// Первый день отметок привычек: привычки отмечаются по дням, поэтому за 7 дней — сегодня и 6 предыдущих.
    func firstHabitDay(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today:
            return today
        case .last7Days:
            return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        }
    }
}

/// Цифры для «Итогов». Только числа — это всё, что уходит в модель.
struct ReflectionStats: Equatable, Codable {
    var period: ReflectionPeriod
    /// Дней в периоде (для привычек): 1 или 7.
    var days: Int
    /// Выполнено за период (по `completedAt`).
    var completed: Int
    /// Создано за период.
    var created: Int
    /// Сейчас не выполнено.
    var active: Int
    /// Сейчас просрочено.
    var overdue: Int
    /// Выполнено за период по приоритетам.
    var completedLow: Int
    var completedMedium: Int
    var completedHigh: Int
    var completedHighest: Int
    var habits: Int
    /// Отметок привычек за период и сколько было возможно (привычка × дни с её создания).
    var habitCheckins: Int
    var habitPossible: Int
    /// Встречи за период (D-44); `nil` — «Встречи из Календаря» выключены или нет доступа.
    var meetings: Int? = nil
    /// Минут во встречах за период; `nil` — как у `meetings`.
    var meetingMinutes: Int? = nil
    /// Границы периода — показываются в выдаче «Итогов за 7 дней», в модель не уходят.
    var periodStart: Date? = nil
    var periodEnd: Date? = nil

    /// «14 октября 12:00 – 21 октября 12:00»; `nil` — границ нет.
    func intervalText(timeZone: TimeZone = .current) -> String? {
        guard let periodStart, let periodEnd else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM HH:mm"
        return "\(formatter.string(from: periodStart)) – \(formatter.string(from: periodEnd))"
    }

    /// Доля выполнения привычек в процентах (0…100), `nil` — привычек нет.
    var habitRatePercent: Int? {
        habitPossible == 0 ? nil : Int((Double(habitCheckins) / Double(habitPossible) * 100).rounded())
    }
}

enum ReflectionService {
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: итоги."

    // MARK: - Цифры

    /// Задачи в корзине входят в «выполнено» и «создано», если это было в периоде, но не в «не выполнено
    /// сейчас» и «просрочено» (решение владельца 2026-10-26, п. 49); окончательно удалённых в базе нет.
    /// `meetingEvents` — события Календаря за период; `nil` — встречи недоступны, и чисел о них нет.
    static func compute(
        tasks: [TaskItem],
        habits: [Habit],
        period: ReflectionPeriod,
        meetingEvents: [CalendarMeeting]? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ReflectionStats {
        let start = period.start(now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let firstHabitDay = period.firstHabitDay(now: now, calendar: calendar)
        let days = (calendar.dateComponents([.day], from: firstHabitDay, to: today).day ?? 0) + 1
        let inPeriod = { (date: Date) in date >= start && date <= now }

        let live = tasks.filter { !$0.isSoftDeleted }
        let completedInPeriod = tasks.filter { task in
            task.isCompleted && task.completedAt.map(inPeriod) == true
        }
        func completed(_ priority: TaskPriority) -> Int {
            completedInPeriod.filter { $0.priority == priority }.count
        }

        var checkins = 0
        var possible = 0
        for habit in habits {
            let habitStart = max(firstHabitDay, calendar.startOfDay(for: habit.createdAt))
            guard habitStart <= today else { continue }
            let keys = Set(habit.completedDayKeys)
            var day = habitStart
            while day <= today {
                possible += 1
                if keys.contains(dayKey(day, calendar: calendar)) { checkins += 1 }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        let meetingTotals = meetingEvents.map { meetingTotals($0, from: start, to: now) }

        return ReflectionStats(
            period: period,
            days: days,
            completed: completedInPeriod.count,
            created: tasks.filter { inPeriod($0.createdAt) }.count,
            active: live.filter { !$0.isCompleted }.count,
            overdue: live.filter { $0.isOverdue(at: now, calendar: calendar) }.count,
            completedLow: completed(.low),
            completedMedium: completed(.medium),
            completedHigh: completed(.high),
            completedHighest: completed(.highest),
            habits: habits.count,
            habitCheckins: checkins,
            habitPossible: possible,
            meetings: meetingTotals?.count,
            meetingMinutes: meetingTotals?.minutes,
            periodStart: start,
            periodEnd: now
        )
    }

    /// Встречи с `start` до `now`: без календаря «BraineeApp» (это задачи) и без событий на весь день
    /// (праздники, дни рождения — не встречи); время — только та часть встречи, что попала в период.
    static func meetingTotals(_ events: [CalendarMeeting], from start: Date, to now: Date) -> (count: Int, minutes: Int) {
        let inPeriod = events.filter { event in
            event.calendarTitle != CalendarEventRules.calendarTitle
                && !event.isAllDay
                && event.start < now
                && event.end > start
        }
        let seconds = inPeriod.reduce(0.0) { total, event in
            total + min(event.end, now).timeIntervalSince(max(event.start, start))
        }
        return (inPeriod.count, Int((seconds / 60).rounded()))
    }

    /// «2 ч 30 мин», «45 мин», «0 мин» — для карточки, копии и запроса.
    static func meetingTimeText(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) мин"
        case (_, 0): return "\(hours) ч"
        default: return "\(hours) ч \(rest) мин"
        }
    }

    /// Ключ дня «yyyy-MM-dd» в часовом поясе `calendar` (как хранятся отметки привычек).
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Запрос и ответ

    static func makeRequest(stats: ReflectionStats) -> LLMRequest {
        LLMRequest(
            messages: [
                LLMMessage(role: .system, content: systemPrompt),
                LLMMessage(role: .user, content: numbersMessage(stats))
            ],
            maxTokens: 800,
            temperature: 0.4
        )
    }

    static let systemPrompt = """
    \(modeMarker)
    Ты помогаешь подвести короткие итоги по списку дел. Тебе дают только числа за период.
    Напиши по-русски 3–5 коротких предложений: что получилось, на что обратить внимание, один практичный совет.
    Опирайся только на эти числа, ничего не выдумывай, не пересказывай их все подряд.
    Без markdown, без списков, без приветствий.
    """

    /// Сообщение с числами — единственное, что модель знает о данных пользователя.
    static func numbersMessage(_ stats: ReflectionStats) -> String {
        let periodText = stats.period == .today ? "сегодня" : "последние 7 дней до момента запроса"
        var lines = [
            "Период: \(periodText).",
            "Выполнено задач: \(stats.completed) (наивысший приоритет: \(stats.completedHighest), высокий: \(stats.completedHigh), средний: \(stats.completedMedium), низкий: \(stats.completedLow)).",
            "Создано задач: \(stats.created).",
            "Не выполнено сейчас: \(stats.active), из них просрочено: \(stats.overdue)."
        ]
        if let rate = stats.habitRatePercent {
            lines.append("Привычек: \(stats.habits), отметок: \(stats.habitCheckins) из \(stats.habitPossible) возможных (\(rate)%).")
        } else {
            lines.append("Привычек нет.")
        }
        if let meetings = stats.meetings, let minutes = stats.meetingMinutes {
            lines.append("Встреч в календаре: \(meetings), во встречах: \(meetingTimeText(minutes: minutes)).")
        }
        return lines.joined(separator: "\n")
    }

    /// Текст ответа без лишних пробелов и markdown-выделений.
    static func parse(_ responseText: String) throws -> String {
        let text = responseText
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}

/// Запрос «Итогов» к модели.
struct ReflectionGenerator {
    let provider: LLMProvider

    func reflection(for stats: ReflectionStats) async throws -> String {
        let response = try await provider.complete(ReflectionService.makeRequest(stats: stats))
        return try ReflectionService.parse(response.text)
    }
}
