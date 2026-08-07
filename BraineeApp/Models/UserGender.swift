//
//  UserGender.swift
//  BraineeApp
//
//  Пол пользователя в профиле (хранится в JSON как String).

import Foundation

enum UserGender: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case male
    case female
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unspecified: "Не указан"
        case .male: "Мужской"
        case .female: "Женский"
        case .other: "Другой"
        }
    }

    static func resolved(from raw: String?) -> UserGender {
        guard let raw, let value = UserGender(rawValue: raw) else { return .unspecified }
        return value
    }
}
