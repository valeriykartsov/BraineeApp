//
//  SettingsSearch.swift
//  BraineeApp
//
//  Поиск по разделам «Профиля»: подходит ли раздел к запросу по его ключевым словам.
//  Вынесено отдельно, чтобы правило сравнения проверялось юнит-тестами.

import Foundation

enum SettingsSearch {
    /// Ключ короче — обратное сравнение не делаем: «пол» иначе совпал бы с «положение».
    static let minStemLength = 4

    /// Раздел подходит, если хотя бы одно слово запроса совпало с каким-нибудь ключом.
    /// Пустой запрос подходит ко всем разделам.
    static func matches(query: String, keywords: [String]) -> Bool {
        let words = queryWords(query)
        guard !words.isEmpty else { return true }
        let normalizedKeywords = keywords.map(normalized)
        return words.contains { word in
            normalizedKeywords.contains { keywordMatches($0, word: word) }
        }
    }

    /// Слово подходит к ключу, если входит в него («уведом» → «уведомлен»)
    /// или начинается с ключа-основы («уведомления» → «уведомлен»).
    static func keywordMatches(_ keyword: String, word: String) -> Bool {
        if keyword.contains(word) { return true }
        return keyword.count >= minStemLength && word.hasPrefix(keyword)
    }

    /// Слова запроса без регистра, «ё» и знаков препинания.
    static func queryWords(_ query: String) -> [String] {
        normalized(query)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ё", with: "е")
    }
}
