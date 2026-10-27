//
//  KeyboardLayoutTests.swift
//  BraineeAppTests
//
//  Панель вкладок не поднимается над клавиатурой (п. 57): верх клавиатуры по её кадру
//  и нижний отступ содержимого вкладок под капсулой панели (п. 60).

import CoreGraphics
import Testing
@testable import BraineeApp

struct KeyboardLayoutTests {
    // iPhone 17: экран 874 pt, низ корня — 840 pt (34 pt под индикатором «домой»).
    private let screenHeight: CGFloat = 874
    private let contentBottom: CGFloat = 840

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

    // Без клавиатуры содержимое резервирует место под капсулу панели вкладок.
    @Test func безКлавиатуры_местоПодКапсулу() {
        #expect(KeyboardLayout.contentBottomInset(tabBarReserve: 68, contentBottom: contentBottom, keyboardTop: nil) == 68)
    }

    // Обычная клавиатура: содержимое (поле чата LLM) поднимается ровно до её верха.
    @Test func клавиатураВышеКапсулы_отступДоВерхаКлавиатуры() {
        #expect(KeyboardLayout.contentBottomInset(tabBarReserve: 68, contentBottom: contentBottom, keyboardTop: 538) == 302)
    }

    // «Призрачная» полоса над клавиатурой (~45 pt) ниже капсулы — ничего не сдвигается.
    @Test func полосаНижеКапсулы_отступПрежний() {
        let phantomTop = screenHeight - 45
        #expect(KeyboardLayout.contentBottomInset(tabBarReserve: 68, contentBottom: contentBottom, keyboardTop: phantomTop) == 68)
    }
}
