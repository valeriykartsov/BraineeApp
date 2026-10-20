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
        try ModelContainerFactory.make(.inMemory)
    }

    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
