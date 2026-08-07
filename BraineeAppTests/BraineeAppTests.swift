//
//  BraineeAppTests.swift
//  BraineeAppTests
//
//  Точка входа набора тестов. Основные сценарии — в соседних файлах *Tests.swift.

import Testing
@testable import BraineeApp

struct BraineeAppTests {
    @Test func тестовыйTargetПодключён_импортРаботает() {
        // Smoke-тест: @testable import BraineeApp доступен из юнит-тестов.
        #expect(MyTasksDocument.currentVersion == 2)
        #expect(TaskInputValidation.detailsMaxLength == 200)
    }
}
