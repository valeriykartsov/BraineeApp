//
//  QuickTaskParserTests.swift
//  BraineeAppTests
//
//  Распознавание в названии новой задачи (п. 46): дата, время, #тег, !приоритет, применение к полям
//  формы и подсказки. «Сейчас» — понедельник 26.10.2026 14:30 (Москва).

import Foundation
import Testing
@testable import BraineeApp

struct QuickTaskParserTests {
    private let calendar: Calendar
    private let now: Date
    private let tags = ["дом", "Работа", "дом и сад"]

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 14, minute: 30))!
    }

    private func day(_ day: Int, _ month: Int, _ year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func parse(_ text: String) -> QuickTaskParse {
        QuickTaskParser.parse(text, tagNames: tags, now: now, calendar: calendar)
    }

    // MARK: - Даты

    // «сегодня», «завтра», «послезавтра» — от сегодняшнего дня; регистр не важен.
    @Test func относительныеДаты() {
        #expect(parse("Сегодня позвонить").day == day(26, 10))
        #expect(parse("завтра позвонить").day == day(27, 10))
        #expect(parse("послезавтра позвонить").day == day(28, 10))
        #expect(parse("послезавтра позвонить").title == "позвонить")
    }

    // 25.10, 25.10.26, 25.10.2026, «25 октября»; прошедшая дата без года — следующий год.
    @Test func точныеДаты() {
        #expect(parse("отчёт 30.10").day == day(30, 10))
        #expect(parse("отчёт 25.10").day == day(25, 10, 2027))
        #expect(parse("отчёт 25.10.26").day == day(25, 10))
        #expect(parse("отчёт 25.10.2026").day == day(25, 10))
        #expect(parse("отчёт 3 ноября").day == day(3, 11))
        #expect(parse("отчёт 25 октября").day == day(25, 10, 2027))
        #expect(parse("отчёт 3 ноября").title == "отчёт")
        #expect(parse("сдать до 30.10.").day == day(30, 10))
    }

    // Несуществующая дата, неполный год и число внутри слова остаются текстом.
    @Test func неДаты_остаютсяТекстом() {
        #expect(parse("отчёт 31.02").day == nil)
        #expect(parse("версия 25.10.2").day == nil)
        #expect(parse("версия 1.2.3").day == nil)
        #expect(parse("назавтра").day == nil)
        #expect(parse("отчёт 31.02").title == "отчёт 31.02")
    }

    // Первая дата применяется, вторая остаётся в названии.
    @Test func двеДаты_перваяПрименяется() {
        let result = parse("завтра перенести на 30.10")
        #expect(result.day == day(27, 10))
        #expect(result.title == "перенести на 30.10")
    }

    // MARK: - Время

    // «10:30» и «в 10:30» (предлог убирается); 24:00 и 9:75 — не время.
    @Test func время() {
        #expect(parse("созвон 10:30").time == .init(hour: 10, minute: 30))
        let withPreposition = parse("созвон в 9:05 завтра")
        #expect(withPreposition.time == .init(hour: 9, minute: 5))
        #expect(withPreposition.title == "созвон")
        #expect(parse("созвон 24:00").time == nil)
        #expect(parse("созвон 9:75").time == nil)
        #expect(parse("Иванов 10:30").title == "Иванов")
    }

    // MARK: - Теги и приоритет

    // Только существующие теги (регистр не важен, имя — как в библиотеке); самое длинное имя; незнакомый — текст.
    @Test func теги() {
        let result = parse("полить #Дом и сад и #работа #новый")
        #expect(result.tagNames == ["дом и сад", "Работа"])
        #expect(result.title == "полить и #новый")
        #expect(parse("купить #дом").tagNames == ["дом"])
        #expect(parse("купить #домик").tagNames.isEmpty)
        #expect(parse("почта a#дом").tagNames.isEmpty)
    }

    // Приоритет словами; без «!» или с цифрой — не приоритет.
    @Test func приоритет() {
        #expect(parse("задача !высокий").priority == .high)
        #expect(parse("задача !Наивысший").priority == .highest)
        #expect(parse("задача !низкий").title == "задача")
        #expect(parse("задача высокий").priority == nil)
        #expect(parse("задача !3").priority == nil)
    }

    // Всё сразу из примера бэклога.
    @Test func всёВместе() {
        let result = parse("завтра в 10:30 купить хлеб #дом !высокий")
        #expect(result.day == day(27, 10))
        #expect(result.time == .init(hour: 10, minute: 30))
        #expect(result.tagNames == ["дом"])
        #expect(result.priority == .high)
        #expect(result.title == "купить хлеб")
    }

    // MARK: - Поля формы

    private var emptyFields: QuickTaskFields {
        QuickTaskFields(hasDeadline: false, hasDeadlineTime: false, deadline: now, priority: .medium, tagNames: [])
    }

    // Дата и время заполняют срок; только время — сегодня в это время.
    @Test func поля_датаИВремя() {
        let both = QuickTaskParser.apply(parse("завтра 10:30 x"), previous: nil, to: emptyFields, now: now, calendar: calendar)
        #expect(both.hasDeadline && both.hasDeadlineTime)
        #expect(both.deadline == calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10, minute: 30)))

        let timeOnly = QuickTaskParser.apply(parse("x 18:00"), previous: nil, to: emptyFields, now: now, calendar: calendar)
        #expect(timeOnly.deadline == calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 18)))

        let dayOnly = QuickTaskParser.apply(parse("x завтра"), previous: nil, to: emptyFields, now: now, calendar: calendar)
        #expect(dayOnly.hasDeadline && !dayOnly.hasDeadlineTime)
        #expect(dayOnly.deadline == day(27, 10))
    }

    // Ручной выбор в форме не затирается, пока метка в тексте не изменилась; новая метка — применяется.
    @Test func поля_ручнойВыборНеЗатирается() {
        let first = parse("завтра x !высокий")
        var fields = QuickTaskParser.apply(first, previous: nil, to: emptyFields, now: now, calendar: calendar)
        fields.priority = .low
        fields.deadline = day(30, 10)

        let typing = parse("завтра x хлеб !высокий")
        let afterTyping = QuickTaskParser.apply(typing, previous: first, to: fields, now: now, calendar: calendar)
        #expect(afterTyping.priority == .low)
        #expect(afterTyping.deadline == day(30, 10))

        let changed = parse("послезавтра x хлеб !наивысший")
        let afterChange = QuickTaskParser.apply(changed, previous: typing, to: afterTyping, now: now, calendar: calendar)
        #expect(afterChange.priority == .highest)
        #expect(afterChange.deadline == day(28, 10))
    }

    // Теги добавляются к выбранным, убранная из текста метка тег не снимает.
    @Test func поля_тегиДобавляются() {
        var fields = emptyFields
        fields.tagNames = ["Работа"]
        let withTag = parse("x #дом")
        let added = QuickTaskParser.apply(withTag, previous: nil, to: fields, now: now, calendar: calendar)
        #expect(added.tagNames == ["Работа", "дом"])

        let removed = QuickTaskParser.apply(parse("x"), previous: withTag, to: added, now: now, calendar: calendar)
        #expect(removed.tagNames == ["Работа", "дом"])
    }

    // MARK: - Подсказки

    // После «#» — теги по введённым буквам, после «!» — приоритеты от наивысшего; иначе — ничего.
    @Test func подсказки() {
        #expect(QuickTaskParser.suggestions(for: "купить #до", tagNames: tags).map(\.title) == ["#дом", "#дом и сад"])
        #expect(QuickTaskParser.suggestions(for: "купить #", tagNames: tags).count == 3)
        #expect(QuickTaskParser.suggestions(for: "x !", tagNames: tags).map(\.title) == ["!наивысший", "!высокий", "!средний", "!низкий"])
        #expect(QuickTaskParser.suggestions(for: "x !в", tagNames: tags).map(\.title) == ["!высокий"])
        #expect(QuickTaskParser.suggestions(for: "купить #дом ", tagNames: tags).isEmpty)
        #expect(QuickTaskParser.suggestions(for: "купить хлеб", tagNames: tags).isEmpty)
    }

    // Нажатие на подсказку заменяет последнее слово и добавляет пробел.
    @Test func подсказка_заменяетПоследнееСлово() {
        let suggestion = QuickTaskSuggestion(insertion: "#дом ", title: "#дом")
        #expect(QuickTaskParser.applying(suggestion, to: "купить #д") == "купить #дом ")
        #expect(QuickTaskParser.applying(suggestion, to: "#д") == "#дом ")
    }
}
