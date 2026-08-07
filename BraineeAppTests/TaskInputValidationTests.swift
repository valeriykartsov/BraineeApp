//
//  TaskInputValidationTests.swift
//  BraineeAppTests
//
//  Проверки ввода названия, описания и тегов.

import Testing
@testable import BraineeApp

struct TaskInputValidationTests {

    @Test func названиеСПробелами_нельзяСохранить() {
        // Пустое или из пробелов название не должно проходить валидацию.
        #expect(TaskInputValidation.canSaveTitle("") == false)
        #expect(TaskInputValidation.canSaveTitle("   ") == false)
        #expect(TaskInputValidation.canSaveTitle("\n\t") == false)
    }

    @Test func обычноеНазвание_можноСохранить() {
        // Нормальное название проходит, пробелы по краям обрезаются.
        #expect(TaskInputValidation.canSaveTitle("Купить молоко") == true)
        #expect(TaskInputValidation.normalizedTitle("  Купить молоко  ") == "Купить молоко")
    }

    @Test func описаниеДлиннееЛимита_обрезаетсяДо200() {
        // Описание длиннее 200 символов обрезается до лимита.
        let long = String(repeating: "а", count: 250)
        let result = TaskInputValidation.clampedDetails(long)
        #expect(result.count == TaskInputValidation.detailsMaxLength)
        #expect(TaskInputValidation.detailsMaxLength == 200)
    }

    @Test func описаниеРовно200_сохраняетсяЦеликом() {
        // Ровно 200 символов — граничное значение, ничего не теряется.
        let exact = String(repeating: "б", count: 200)
        #expect(TaskInputValidation.clampedDetails(exact) == exact)
    }

    @Test func пустойТег_нельзяСоздать() {
        // Пустое имя тега отклоняется.
        #expect(TaskInputValidation.canCreateTag(name: "  ", existingNames: []) == false)
    }

    @Test func дубликатТегаБезУчётаРегистра_нельзяСоздать() {
        // «Работа» и «работа» считаются одним и тем же тегом.
        #expect(
            TaskInputValidation.canCreateTag(name: "работа", existingNames: ["Работа"]) == false
        )
        #expect(
            TaskInputValidation.canCreateTag(name: "Спорт", existingNames: ["Работа"]) == true
        )
    }

    @Test func переименованиеТега_тожеИмяДопустимо() {
        // Оставить то же имя (другой регистр) при правке — можно.
        #expect(
            TaskInputValidation.canRenameTag(
                name: "работа",
                existingNames: ["Работа", "Спорт"],
                currentName: "Работа"
            ) == true
        )
    }

    @Test func переименованиеТега_вСуществующийДубликат_нельзя() {
        // Нельзя переименовать тег в имя другого тега.
        #expect(
            TaskInputValidation.canRenameTag(
                name: "Спорт",
                existingNames: ["Работа", "Спорт"],
                currentName: "Работа"
            ) == false
        )
    }

    @Test func пустоеНазваниеГруппы_нельзяСохранить() {
        #expect(TaskInputValidation.canSaveGroupName("  ") == false)
        #expect(TaskInputValidation.canSaveGroupName("Проекты") == true)
    }
}
