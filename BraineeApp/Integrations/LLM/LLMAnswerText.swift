//
//  LLMAnswerText.swift
//  BraineeApp
//
//  Текст ответа ассистента для кнопки «Копировать» (бэклог, п. 8): то же, что видно на карточке,
//  обычным текстом. Ничего не отправляет и не меняет данные.

import Foundation

enum LLMAnswerText {
    /// «Итоги»: заголовок, цифры, которые посчитало приложение, и текст модели.
    static func reflection(text: String, stats: ReflectionStats) -> String {
        var lines = [stats.period.reportTitle]
        if stats.period == .last7Days, let interval = stats.intervalText() {
            lines.append(interval)
        }
        lines += [
            "Выполнено: \(stats.completed)",
            "Создано: \(stats.created)",
            "Просрочено: \(stats.overdue) из \(stats.active) открытых"
        ]
        if let rate = stats.habitRatePercent {
            lines.append("Привычки: \(stats.habitCheckins) из \(stats.habitPossible) (\(rate)%)")
        }
        if let meetings = stats.meetingsText {
            lines.append("Встречи: \(meetings)")
        }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            lines.append("")
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    /// «План дня»: заголовок, общий совет, пункты «время или номер — название — пояснение», пометки.
    static func dayPlan(_ plan: DayPlan) -> String {
        var lines = ["План на сегодня"]
        let summary = plan.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            lines.append(summary)
        }
        lines.append("")
        for (index, item) in plan.items.enumerated() {
            var line = "\(item.suggestedTime ?? "\(index + 1).") \(item.title)"
            let note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                line += " — \(note)"
            }
            lines.append(line)
        }
        if !plan.notes.isEmpty {
            lines.append("")
            lines.append(contentsOf: plan.notes)
        }
        return lines.joined(separator: "\n")
    }

    /// «Матрица» (D-42): заголовок, общий совет, группы по действиям «• название — горизонт. совет», пометки.
    static func matrixReview(_ review: MatrixReview) -> String {
        var lines = ["Разбор задач без срока"]
        let summary = review.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            lines.append(summary)
        }
        for action in MatrixReviewAction.allCases {
            let items = review.items(for: action)
            guard !items.isEmpty else { continue }
            lines.append("")
            lines.append(action.title)
            for item in items {
                lines.append("• " + matrixLine(item))
            }
        }
        if !review.notes.isEmpty {
            lines.append("")
            lines.append(contentsOf: review.notes)
        }
        return lines.joined(separator: "\n")
    }

    /// «Название — на этой неделе. Совет»; без горизонта и совета — только название.
    static func matrixLine(_ item: MatrixReviewItem) -> String {
        let note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = [item.horizon?.title, note.isEmpty ? nil : note].compactMap { $0 }.joined(separator: ". ")
        return detail.isEmpty ? item.title : "\(item.title) — \(detail)"
    }
}

extension ReflectionStats {
    /// «3 (2 ч 30 мин)» для карточки и копии «Итогов»; `nil` — встречи не учитывались (D-44).
    var meetingsText: String? {
        guard let meetings, let meetingMinutes else { return nil }
        return "\(meetings) (\(ReflectionService.meetingTimeText(minutes: meetingMinutes)))"
    }
}
