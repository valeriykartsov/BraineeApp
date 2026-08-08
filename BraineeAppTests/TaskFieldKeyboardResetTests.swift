//
//  TaskFieldKeyboardResetTests.swift
//  BraineeAppTests
//

import Testing
@testable import BraineeApp

struct TaskFieldKeyboardResetTests {
    @Test func сбросОписания_когдаФокусУжеСнят() {
        // Клавиатура часто снимает фокус до action «Отмена» — сброс всё равно должен найти описание.
        let target = TaskFieldKeyboardReset.resetTarget(
            focused: nil,
            lastFocused: .details,
            title: "Задача",
            titleCommitted: "Задача",
            details: "новый текст",
            detailsCommitted: "старый"
        )
        #expect(target == .details)
        #expect(
            TaskFieldKeyboardReset.canReset(
                focused: nil,
                lastFocused: .details,
                title: "Задача",
                titleCommitted: "Задача",
                details: "новый текст",
                detailsCommitted: "старый"
            )
        )
    }

    @Test func сбросНеактивен_безИзменений() {
        // Без dirty «Отмена» не должна предлагать сброс.
        #expect(
            TaskFieldKeyboardReset.resetTarget(
                focused: .details,
                lastFocused: .details,
                title: "A",
                titleCommitted: "A",
                details: "B",
                detailsCommitted: "B"
            ) == nil
        )
    }

    @Test func сбросНазвания_приФокусеНаНазвании() {
        // При фокусе на названии сбрасываем именно его, даже если описание тоже dirty.
        let target = TaskFieldKeyboardReset.resetTarget(
            focused: .title,
            lastFocused: .title,
            title: "новое",
            titleCommitted: "старое",
            details: "другое",
            detailsCommitted: "исходное"
        )
        #expect(target == .title)
    }

    @Test func fallbackНаОписание_еслиНетФокусаИLastFocused() {
        // Крайний случай: оба фокуса nil, но описание изменено.
        let target = TaskFieldKeyboardReset.resetTarget(
            focused: nil,
            lastFocused: nil,
            title: "A",
            titleCommitted: "A",
            details: "новое",
            detailsCommitted: ""
        )
        #expect(target == .details)
    }
}
