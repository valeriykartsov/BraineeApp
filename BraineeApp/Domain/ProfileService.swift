//
//  ProfileService.swift
//  BraineeApp
//
//  Профиль пользователя (roadmap DOM-2b). Раньше логика жила в ProfileView
//  и AppearanceSettingsView.

import Foundation
import SwiftData

@MainActor
struct ProfileService {
    let context: ModelContext
    /// См. TaskService.onChange.
    var onChange: (ModelContext) -> Void = { $0.didChange() }

    /// Профиль один; если его нет (новая установка или в JSON его не было) — создаётся пустой.
    @discardableResult
    func ensureProfile() -> UserProfile {
        if let existing = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            return existing
        }
        let profile = UserProfile(displayName: "")
        context.insert(profile)
        onChange(context)
        return profile
    }

    func update(name: String, age: Int?, gender: UserGender, avatarData: Data?) {
        let profile = ensureProfile()
        profile.displayName = name
        profile.age = age
        profile.gender = gender
        profile.avatarData = avatarData
        onChange(context)
    }

    /// Тема и акцент хранятся в UserDefaults (@AppStorage во View).
    /// После их смены вызываем onChange, как после любого изменения; в автобэкап тема и акцент
    /// попадают из UserDefaults (AppDataPersistence.exportProfile).
    func appearanceDidChange() {
        onChange(context)
    }
}
