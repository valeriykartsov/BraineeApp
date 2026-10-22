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
    /// Журнал сессии (п. 16); в тестах — свой экземпляр.
    var log: SessionLog = .shared

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
        // Аватар — только факт смены, без данных (п. 16).
        let changes = [
            SessionLogDiff.line("Имя", SessionLogDiff.quoted(profile.displayName), SessionLogDiff.quoted(name)),
            SessionLogDiff.line(
                "Возраст",
                profile.age.map(String.init) ?? SessionLogDiff.none,
                age.map(String.init) ?? SessionLogDiff.none
            ),
            SessionLogDiff.line("Пол", profile.gender.title, gender.title),
            profile.avatarData != avatarData ? "Аватар изменён" : nil
        ].compactMap { $0 }
        if !changes.isEmpty {
            log.add(.profile, "Профиль изменён", changes: changes)
        }
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
