//
//  AutoBackup.swift
//  BraineeApp
//
//  Автобэкап JSON (roadmap SD-4, D-04): при уходе в фон, не чаще раза в 24 часа,
//  хранятся последние 7 файлов в `Application Support/Backups/auto/`.
//  Формат — тот же BackupDocument, что и у ручного экспорта (D-16), поэтому SD-5 восстановит любой из них.

import Foundation
import SwiftData

struct AutoBackup {
    static let minimumInterval: TimeInterval = 24 * 60 * 60
    static let keepCount = 7
    static let filePrefix = "auto-"

    /// Папка только для автобэкапов: ротация не трогает `pre-swiftdata-*` и чужие файлы.
    let directory: URL

    init(directory: URL = AutoBackup.standardDirectory) {
        self.directory = directory
    }

    static var standardDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("auto", isDirectory: true)
    }

    /// Пора ли делать бэкап. Если часы ушли назад (последний бэкап «в будущем») — пора, иначе бэкапы встанут.
    static func isDue(lastBackupAt: Date?, now: Date) -> Bool {
        guard let lastBackupAt else { return true }
        return now < lastBackupAt || now.timeIntervalSince(lastBackupAt) >= minimumInterval
    }

    /// Делает бэкап, если пора, и оставляет последние `keepCount` файлов. Возвращает новый файл или nil.
    @MainActor
    @discardableResult
    func performIfDue(context: ModelContext, now: Date = .now) throws -> URL? {
        guard Self.isDue(lastBackupAt: backupFiles().last.flatMap { Self.date(fromFileName: $0.lastPathComponent) }, now: now) else {
            return nil
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(Self.fileName(for: now))
        try BackupDocument.make(from: context, now: now).encoded().write(to: url, options: .atomic)

        for old in backupFiles().dropLast(Self.keepCount) {
            try? FileManager.default.removeItem(at: old)
        }
        return url
    }

    /// Файлы автобэкапа от старых к новым (имя содержит время в UTC, поэтому сортировка по имени верна).
    func backupFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { Self.date(fromFileName: $0) != nil }
            .sorted()
            .map { directory.appendingPathComponent($0) }
    }

    // MARK: - Имя файла: auto-20261020-173000.json (UTC)

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    static func fileName(for date: Date) -> String {
        "\(filePrefix)\(formatter.string(from: date)).json"
    }

    static func date(fromFileName name: String) -> Date? {
        guard name.hasPrefix(filePrefix), name.hasSuffix(".json") else { return nil }
        let stamp = name.dropFirst(filePrefix.count).dropLast(".json".count)
        return formatter.date(from: String(stamp))
    }
}
