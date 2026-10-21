//
//  SettingsSearchTests.swift
//  BraineeAppTests
//
//  Поиск по разделам «Профиля» (бэклог, п. 5).

import Testing
@testable import BraineeApp

struct SettingsSearchTests {
    private let notifications = ["настройки", "уведомлен", "напомина", "пуш"]

    // Пустой запрос или одни пробелы показывают все разделы.
    @Test func пустойЗапрос_подходитКоВсем() {
        #expect(SettingsSearch.matches(query: "", keywords: notifications))
        #expect(SettingsSearch.matches(query: "   ", keywords: notifications))
    }

    // Начало слова находит раздел, как и раньше.
    @Test func началоКлюча_находит() {
        #expect(SettingsSearch.matches(query: "уведом", keywords: notifications))
        #expect(SettingsSearch.matches(query: "НАСТР", keywords: notifications))
    }

    // Слово длиннее ключа-основы тоже находит («уведомления» — ключ «уведомлен»).
    @Test func словоДлиннееКлюча_находит() {
        #expect(SettingsSearch.matches(query: "уведомления", keywords: notifications))
        #expect(SettingsSearch.matches(query: "Напоминания", keywords: notifications))
    }

    // Короткий ключ не совпадает с длинным словом: «положение» не находит «пол».
    @Test func короткийКлюч_неСовпадаетСДлиннымСловом() {
        #expect(SettingsSearch.matches(query: "положение", keywords: ["пол", "имя"]) == false)
        #expect(SettingsSearch.matches(query: "пушки", keywords: notifications) == false)
    }

    // «ё» и «е» не различаются ни в запросе, ни в ключе.
    @Test func ёИЕ_неРазличаются() {
        #expect(SettingsSearch.matches(query: "темная", keywords: ["тёмная"]))
        #expect(SettingsSearch.matches(query: "удалённые", keywords: ["удаленные"]))
    }

    // Из нескольких слов достаточно одного совпавшего; знаки препинания не мешают.
    @Test func несколькоСлов_достаточноОдного() {
        #expect(SettingsSearch.matches(query: "резервная копия", keywords: ["бэкап", "резерв"]))
        #expect(SettingsSearch.matches(query: "уведомления, пожалуйста!", keywords: notifications))
    }

    // Запрос без совпадений раздел не показывает.
    @Test func нетСовпадений_неПодходит() {
        #expect(SettingsSearch.matches(query: "привычки", keywords: notifications) == false)
    }
}
