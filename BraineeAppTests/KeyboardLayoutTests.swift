//
//  KeyboardLayoutTests.swift
//  BraineeAppTests
//
//  Панель вкладок не поднимается над клавиатурой (п. 57): верх клавиатуры по её кадру
//  и нижний отступ содержимого вкладок.

import CoreGraphics
import Testing
@testable import BraineeApp

struct KeyboardLayoutTests {
    // iPhone 17: экран 874 pt, верх панели вкладок — 790 pt (панель 50 pt + 34 pt под индикатором).
    private let screenHeight: CGFloat = 874
    private let tabBarTop: CGFloat = 790

    // Клавиатура на экране: верх — её minY.
    @Test func клавиатураНаЭкране_верхРавенMinY() {
        let frame = CGRect(x: 0, y: 538, width: 402, height: 336)
        #expect(KeyboardLayout.keyboardTop(frameEnd: frame, screenHeight: screenHeight) == 538)
    }

    // Скрытая клавиатура (кадр за экраном или пустой) — клавиатуры нет.
    @Test func клавиатураЗаЭкраномИлиПустая_нет() {
        let offscreen = CGRect(x: 0, y: 874, width: 402, height: 336)
        #expect(KeyboardLayout.keyboardTop(frameEnd: offscreen, screenHeight: screenHeight) == nil)
        #expect(KeyboardLayout.keyboardTop(frameEnd: .zero, screenHeight: screenHeight) == nil)
    }

    // Без клавиатуры у содержимого нет отступа.
    @Test func безКлавиатуры_отступаНет() {
        #expect(KeyboardLayout.contentBottomPadding(tabBarTop: tabBarTop, keyboardTop: nil) == 0)
    }

    // Обычная клавиатура: содержимое (поле чата LLM) поднимается ровно до её верха.
    @Test func клавиатураВышеПанели_отступДоВерхаКлавиатуры() {
        #expect(KeyboardLayout.contentBottomPadding(tabBarTop: tabBarTop, keyboardTop: 538) == 252)
    }

    // «Призрачная» полоса над клавиатурой (~45 pt) ниже верха панели — ничего не сдвигается.
    @Test func полосаНижеВерхаПанели_отступаНет() {
        let phantomTop = screenHeight - 45
        #expect(KeyboardLayout.contentBottomPadding(tabBarTop: tabBarTop, keyboardTop: phantomTop) == 0)
    }
}
