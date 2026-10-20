//
//  UserProfile.swift
//  BraineeApp
//
//  Профиль пользователя: имя, аватар, возраст, пол.

import Foundation
import SwiftData

@Model
final class UserProfile {
    /// Один uuid — одна запись: повторная вставка обновляет существующую (upsert), а не создаёт дубль (D-17).
    #Unique<UserProfile>([\.uuid])

    /// Стабильный идентификатор профиля (DOM-3); в profile.json — поле `id`.
    var uuid: UUID
    var displayName: String
    var avatarData: Data?
    /// Возраст; `nil` — не указан.
    var age: Int?
    /// Сырое значение `UserGender` для SwiftData.
    var genderRaw: String
    var createdAt: Date

    var gender: UserGender {
        get { UserGender.resolved(from: genderRaw) }
        set { genderRaw = newValue.rawValue }
    }

    init(
        uuid: UUID = UUID(),
        displayName: String = "",
        avatarData: Data? = nil,
        age: Int? = nil,
        gender: UserGender = .unspecified,
        createdAt: Date = .now
    ) {
        self.uuid = uuid
        self.displayName = displayName
        self.avatarData = avatarData
        self.age = age
        self.genderRaw = gender.rawValue
        self.createdAt = createdAt
    }
}
