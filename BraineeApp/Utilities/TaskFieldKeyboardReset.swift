//
//  TaskFieldKeyboardReset.swift
//  BraineeApp
//
//  Логика «Отмена» / «ОК» над клавиатурой для названия и описания задачи.
//  Вынесена отдельно, чтобы юнит-тесты не зависели от SwiftUI FocusState.

import Foundation

enum TaskFormTextField: Equatable {
    case title
    case details
}

enum TaskFieldKeyboardReset {
    /// Какое поле сбрасывать: фокус, последнее сфокусированное или dirty-fallback.
    static func resetTarget(
        focused: TaskFormTextField?,
        lastFocused: TaskFormTextField?,
        title: String,
        titleCommitted: String,
        details: String,
        detailsCommitted: String
    ) -> TaskFormTextField? {
        let preferred = focused ?? lastFocused
        switch preferred {
        case .details where details != detailsCommitted:
            return .details
        case .title where title != titleCommitted:
            return .title
        case .none, .details, .title:
            if details != detailsCommitted { return .details }
            if title != titleCommitted { return .title }
            return nil
        }
    }

    static func canReset(
        focused: TaskFormTextField?,
        lastFocused: TaskFormTextField?,
        title: String,
        titleCommitted: String,
        details: String,
        detailsCommitted: String
    ) -> Bool {
        resetTarget(
            focused: focused,
            lastFocused: lastFocused,
            title: title,
            titleCommitted: titleCommitted,
            details: details,
            detailsCommitted: detailsCommitted
        ) != nil
    }
}
