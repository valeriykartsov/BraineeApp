//
//  GroupCollapseLogicTests.swift
//  BraineeAppTests
//
//  Свернуть / развернуть все группы: оставшиеся открываются или закрываются.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct GroupCollapseLogicTests {

    @Test func collapsible_толькоГруппыСЗадачами() throws {
        let container = try TestHelpers.makeContainer()
        let withTasks = TaskGroup(name: "A", category: .tasks)
        let empty = TaskGroup(name: "B", category: .tasks)
        let task = TaskItem(title: "t", category: .tasks, group: withTasks)
        container.mainContext.insert(withTasks)
        container.mainContext.insert(empty)
        container.mainContext.insert(task)

        let ids = GroupCollapseLogic.collapsibleIDs(
            groups: [withTasks, empty],
            tasks: [task]
        )
        #expect(ids == [withTasks.uuid])
    }

    @Test func nextAction_всеОткрыты_свернуть() {
        // Все раскрыты → следующее действие «свернуть».
        let a = UUID()
        let b = UUID()
        #expect(
            GroupCollapseLogic.nextActionIsExpand(
                collapsibleIDs: [a, b],
                collapsedIDs: []
            ) == false
        )
    }

    @Test func nextAction_частьСвёрнута_развернуть() {
        // Часть открыта → «развернуть» откроет оставшиеся.
        let a = UUID()
        let b = UUID()
        #expect(
            GroupCollapseLogic.nextActionIsExpand(
                collapsibleIDs: [a, b],
                collapsedIDs: [a]
            ) == true
        )
    }

    @Test func expanding_открываетТолькоОставшиеся() {
        // Уже открытые не трогаем; закрытые убираем из collapsed.
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let result = GroupCollapseLogic.expanding(
            collapsibleIDs: [a, b],
            collapsedIDs: [a, c]
        )
        #expect(result == [c])
        #expect(!result.contains(a))
        #expect(!result.contains(b))
    }

    @Test func collapsing_закрываетТолькоОткрытые() {
        // Уже закрытые остаются; открытые добавляются в collapsed.
        let a = UUID()
        let b = UUID()
        let result = GroupCollapseLogic.collapsing(
            collapsibleIDs: [a, b],
            collapsedIDs: [a]
        )
        #expect(result == [a, b])
    }
}
