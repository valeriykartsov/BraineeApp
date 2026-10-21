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
        var lines = [
            stats.period == .today ? "Итоги дня" : "Итоги недели",
            "Выполнено: \(stats.completed)",
            "Создано: \(stats.created)",
            "Просрочено: \(stats.overdue) из \(stats.active) открытых"
        ]
        if let rate = stats.habitRatePercent {
            lines.append("Привычки: \(stats.habitCheckins) из \(stats.habitPossible) (\(rate)%)")
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
}
