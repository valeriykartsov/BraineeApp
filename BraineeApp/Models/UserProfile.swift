//
//  UserProfile.swift
//  BraineeApp
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var displayName: String
    var avatarData: Data?
    var createdAt: Date

    init(displayName: String = "", avatarData: Data? = nil, createdAt: Date = .now) {
        self.displayName = displayName
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}
