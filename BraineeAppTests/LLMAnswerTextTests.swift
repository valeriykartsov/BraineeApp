//
//  LLMAnswerTextTests.swift
//  BraineeAppTests
//
//  Текст ответа ассистента для «Копировать» (бэклог, п. 8).

import Foundation
import Testing
@testable import BraineeApp

struct LLMAnswerTextTests {
    private func stats(period: ReflectionPeriod, habitPossible: Int) -> ReflectionStats {
        ReflectionStats(
            period: period, days: 1, completed: 3, created: 2, active: 5, overdue: 1,
            completedLow: 0, completedMedium: 3, completedHigh: 0, completedHighest: 0,
            habits: 2, habitCheckins: 1, habitPossible: habitPossible
        )
    }

    // «Итоги»: цифры, как на карточке, затем текст модели через пустую строку.
    @Test func итоги_цифрыИТекст() {
        let text = LLMAnswerText.reflection(text: "  Хороший день.  ", stats: stats(period: .today, habitPossible: 2))

        #expect(text == """
        Итоги дня
        Выполнено: 3
        Создано: 2
        Просрочено: 1 из 5 открытых
        Привычки: 1 из 2 (50%)

        Хороший день.
        """)
    }

    // Встречи учитывались (D-44) — строка «Встречи: число (время)» после привычек.
    @Test func итогиСоВстречами_строкаВстреч() {
        var withMeetings = stats(period: .today, habitPossible: 2)
        withMeetings.meetings = 3
        withMeetings.meetingMinutes = 150

        let text = LLMAnswerText.reflection(text: "", stats: withMeetings)

        #expect(text.hasSuffix("Привычки: 1 из 2 (50%)\nВстречи: 3 (2 ч 30 мин)"))
    }

    // Без привычек строки «Привычки» нет; пустой текст модели не добавляет пустых строк.
    @Test func итогиБезПривычек_безЛишнихСтрок() {
        let text = LLMAnswerText.reflection(text: "", stats: stats(period: .week, habitPossible: 0))

        #expect(text.hasPrefix("Итоги недели\n"))
        #expect(!text.contains("Привычки"))
        #expect(!text.hasSuffix("\n"))
    }

    // «План дня»: время или номер, название, пояснение через тире, пометки в конце.
    @Test func планДня_пунктыИПометки() {
        let plan = DayPlan(
            summary: "Сначала важное.",
            items: [
                DayPlanItem(taskUUID: UUID(), title: "Позвонить в банк", priority: .high, suggestedTime: "09:00", note: "до обеда"),
                DayPlanItem(taskUUID: UUID(), title: "Купить продукты", priority: .low, suggestedTime: nil, note: "")
            ],
            notes: ["Одна задача не вошла в план."]
        )

        #expect(LLMAnswerText.dayPlan(plan) == """
        План на сегодня
        Сначала важное.

        09:00 Позвонить в банк — до обеда
        2. Купить продукты

        Одна задача не вошла в план.
        """)
    }
}
