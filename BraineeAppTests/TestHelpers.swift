//
//  TestHelpers.swift
//  BraineeAppTests
//
//  Общие помощники для юнит-тестов: in-memory SwiftData и даты.

import Foundation
import SwiftData
@testable import BraineeApp

enum TestHelpers {
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TaskItem.self, TaskGroup.self, TaskTag.self, UserProfile.self,
            configurations: configuration
        )
    }

    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
