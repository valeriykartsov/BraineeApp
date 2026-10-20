//
//  CalendarLinks.swift
//  BraineeApp
//
//  Связи «задача → событие» (D-22): служебный кэш в `Application Support/BraineeApp/calendar-links.json`,
//  не в SwiftData и не в бэкапе. Потеря файла не страшна — события находятся по метке в url.

import Foundation

struct CalendarLinks: Codable, Equatable {
    /// Календарь «BraineeApp», в который пишет экспорт.
    var calendarID: String?
    /// uuid задачи (строкой) → eventIdentifier.
    var events: [String: String] = [:]
}

@MainActor
protocol CalendarLinksStoring: AnyObject {
    func load() -> CalendarLinks
    func save(_ links: CalendarLinks) throws
}

@MainActor
final class CalendarLinksFile: CalendarLinksStoring {
    static let fileName = "calendar-links.json"

    let url: URL

    init(url: URL) {
        self.url = url
    }

    /// Рядом с хранилищем: `Application Support/BraineeApp/calendar-links.json`.
    static func standard() -> CalendarLinksFile {
        CalendarLinksFile(
            url: ModelContainerFactory.standardStoreURL
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
        )
    }

    /// Нет файла или он битый — пустые связи: экспорт восстановит их по меткам событий.
    func load() -> CalendarLinks {
        guard let data = try? Data(contentsOf: url),
              let links = try? JSONDecoder().decode(CalendarLinks.self, from: data)
        else { return CalendarLinks() }
        return links
    }

    func save(_ links: CalendarLinks) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(links).write(to: url, options: .atomic)
    }
}
