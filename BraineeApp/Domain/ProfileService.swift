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
    var onChange: (ModelContext) -> Void = { $0.persistToJSON() }

    /// Профиль один; если его нет (обычно он создаётся при загрузке JSON) — создаётся пустой.
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

    /// Тема и акцент хранятся в UserDefaults (@AppStorage во View), но дублируются в profile.json.
    /// После их смены нужно сохранить профиль, чтобы копия в JSON не отставала.
    func appearanceDidChange() {
        onChange(context)
    }
}
