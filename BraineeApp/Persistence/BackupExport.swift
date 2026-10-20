//
//  BackupExport.swift
//  BraineeApp
//
//  Ручной бэкап: один JSON-файл с задачами, группами, тегами, привычками и профилем (без аватара).
//  Внутри — те же MyTasksDocument и ProfileDocument, что и в рабочих JSON, поэтому формат
//  записей не дублируется и старые бэкапы будут читаться теми же decode-правилами.

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: Codable {
    static let formatID = "braineeapp.backup"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var tasks: MyTasksDocument
    var profile: ProfileDocument

    enum BackupError: LocalizedError {
        case notABackup
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notABackup:
                "Файл не является резервной копией BraineeApp."
            case .newerVersion(let version):
                "Резервная копия создана более новой версией приложения (формат \(version))."
            }
        }
    }

    /// Снимок текущего состояния SwiftData, включая задачи в корзине.
    static func make(from context: ModelContext, now: Date = .now) -> BackupDocument {
        var tasks = AppDataPersistence.exportTasks(from: context)
        // Как в saveTasks: в бэкап попадает то же, что попало бы в mytasks.json.
        tasks.normalizeRecords()
        tasks.lastSavedAt = now
        var profile = AppDataPersistence.exportProfile(from: context)
        // Аватар не кладём в бэкап, чтобы файл оставался лёгким (D-16).
        // Восстановление (SD-5) поэтому не должно стирать текущий аватар.
        profile.avatarBase64 = nil
        return BackupDocument(
            format: formatID,
            version: currentVersion,
            exportedAt: now,
            tasks: tasks,
            profile: profile
        )
    }

    /// Имя по умолчанию: BraineeApp-backup-2026-10-20-1630.json (дата — время экспорта).
    static func defaultFileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "BraineeApp-backup-\(formatter.string(from: date)).json"
    }

    /// Короткая сводка для сообщения после экспорта — по ней удобно сверить данные вручную.
    var summary: String {
        let deleted = tasks.tasks.filter(\.isDeleted).count
        let active = tasks.tasks.count - deleted
        return "Задач: \(active), в корзине: \(deleted), групп: \(tasks.groups.count), "
            + "тегов: \(tasks.tags.count), привычек: \(tasks.habits.count)."
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Сначала проверяем заголовок, чтобы отличить «не бэкап» и «новая версия» от битого файла.
    static func decode(from data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Header: Decodable {
            var format: String?
            var version: Int?
        }
        let header = try decoder.decode(Header.self, from: data)
        guard header.format == formatID else { throw BackupError.notABackup }
        if let version = header.version, version > currentVersion {
            throw BackupError.newerVersion(version)
        }
        return try decoder.decode(BackupDocument.self, from: data)
    }
}

/// Обёртка для системного fileExporter: готовые байты бэкапа.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
