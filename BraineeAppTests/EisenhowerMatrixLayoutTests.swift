//
//  EisenhowerMatrixLayoutTests.swift
//  BraineeAppTests
//
//  Превью задач в карточке матрицы: лимит и «...».

import Testing
@testable import BraineeApp

struct EisenhowerMatrixLayoutTests {

    @Test func превью_ровноЛимит_безOverflow() {
        // Три задачи — все видны, «...» нет.
        let items = ["A", "B", "C"]
        let preview = EisenhowerMatrixLayout.preview(items: items)
        #expect(preview.visible == items)
        #expect(preview.showsOverflow == false)
    }

    @Test func превью_большеЛимита_показываетOverflow() {
        // Четыре и больше — первые три и флаг «...».
        let items = Array(1...5).map(String.init)
        let preview = EisenhowerMatrixLayout.preview(items: items)
        #expect(preview.visible == ["1", "2", "3"])
        #expect(preview.showsOverflow == true)
        #expect(EisenhowerMatrixLayout.previewTaskLimit == 3)
    }

    @Test func превью_пусто_безOverflow() {
        let preview = EisenhowerMatrixLayout.preview(items: [String]())
        #expect(preview.visible.isEmpty)
        #expect(preview.showsOverflow == false)
    }
}
