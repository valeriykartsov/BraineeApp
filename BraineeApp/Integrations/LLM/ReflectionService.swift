//
//  ReflectionService.swift
//  BraineeApp
//
//  «Итоги» (LLM-5, D-31): цифры за сегодня или текущую неделю считает код; модель получает
//  только числа (без названий задач и привычек) и формулирует короткий текст. Данные не меняются.
//  Встречи из Календаря (D-44) — тоже только числа: сколько встреч и сколько времени в них.

import Foundation

enum ReflectionPeriod: String, CaseIterable, Identifiable, Codable {
    case today
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Сегодня"
        case .week: "Неделя"
        }
    }

    /// Начало периода: начало дня или начало недели (первый день недели — по `calendar.firstWeekday`,
    /// как в Календаре приложения). Конец — `now`.
    func start(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today:
            return today
        case .week:
            let weekday = calendar.component(.weekday, from: today)
            let offset = (weekday - calendar.firstWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }
    }
}

/// Цифры для «Итогов». Только числа — это всё, что уходит в модель.
struct ReflectionStats: Equatable, Codable {
    var period: ReflectionPeriod
    /// Дней в периоде с начала по сегодня включительно.
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

    /// Доля выполнения привычек в процентах (0…100), `nil` — привычек нет.
    var habitRatePercent: Int? {
        habitPossible == 0 ? nil : Int((Double(habitCheckins) / Double(habitPossible) * 100).rounded())
    }
}

enum ReflectionService {
    /// Метка режима в инструкции — по ней отладочная заглушка выбирает ответ.
    static let modeMarker = "Режим: итоги."

    // MARK: - Цифры

    /// Мягко удалённые задачи не учитываются. `meetingEvents` — события Календаря за период;
    /// `nil` — встречи недоступны, и чисел о них нет.
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
        let days = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let inPeriod = { (date: Date) in date >= start && date <= now }

        let live = tasks.filter { !$0.isSoftDeleted }
        let completedInPeriod = live.filter { task in
            task.isCompleted && task.completedAt.map(inPeriod) == true
        }
        func completed(_ priority: TaskPriority) -> Int {
            completedInPeriod.filter { $0.priority == priority }.count
        }

        var checkins = 0
        var possible = 0
        for habit in habits {
            let habitStart = max(start, calendar.startOfDay(for: habit.createdAt))
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
            created: live.filter { inPeriod($0.createdAt) }.count,
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
            meetingMinutes: meetingTotals?.minutes
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
        let periodText = stats.period == .today ? "сегодня" : "текущая неделя, дней: \(stats.days)"
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
