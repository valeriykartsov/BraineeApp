//
//  UserProfile.swift
//  BraineeApp
//
//  Профиль пользователя: имя, аватар, возраст, пол.

import Foundation
import SwiftData

@Model
final class UserProfile {
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
        displayName: String = "",
        avatarData: Data? = nil,
        age: Int? = nil,
        gender: UserGender = .unspecified,
        createdAt: Date = .now
    ) {
        self.displayName = displayName
        self.avatarData = avatarData
        self.age = age
        self.genderRaw = gender.rawValue
        self.createdAt = createdAt
    }
}
