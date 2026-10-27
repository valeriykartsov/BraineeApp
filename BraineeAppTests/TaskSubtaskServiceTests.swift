//
//  TaskSubtaskServiceTests.swift
//  BraineeAppTests
//
//  Подзадачи в форме и TaskService (D-41): правила (10 штук, 50 символов, пустые отбрасываются),
//  сохранение вместе с формой, счётчик «2/5», снимок формы, строка журнала, настройка отображения.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct TaskSubtaskServiceTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let log = SessionLog()

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private var service: TaskService {
        TaskService(context: context, onChange: { _ in }, log: log)
    }

    private func form(_ subtasks: [SubtaskDraft]?) -> TaskFormData {
        TaskFormData(
            title: "Переезд",
            deadline: nil,
            hasDeadlineTime: false,
            reminderOffsets: [],
            priority: .medium,
            status: .new,
            taskDetails: "",
            selectedTags: [],
            subtasks: subtasks
        )
    }

    // Пустые строки убираются, текст обрезается по краям и до 50 символов, подзадач — не больше 10.
    @Test func правила_пустыеДлинаИКоличество() {
        let long = String(repeating: "я", count: 60)
        let drafts = [SubtaskDraft(title: "  Коробки  "), SubtaskDraft(title: "   "), SubtaskDraft(title: long)]
            + (1...12).map { SubtaskDraft(title: "Шаг \($0)") }

        let result = TaskSubtaskRules.normalized(drafts)

        #expect(result.count == 10)
        #expect(result[0].title == "Коробки")
        #expect(result[1].title.count == 50)
        #expect(result.last?.title == "Шаг 8")
    }

    // Создание: подзадачи сохраняются по порядку; счётчик «выполнено/всего».
    @Test func создание_сохраняетПодзадачиПоПорядку() throws {
        let task = service.create(from: form([
            SubtaskDraft(title: "Коробки", isDone: true),
            SubtaskDraft(title: "Грузчики"),
            SubtaskDraft(title: ""),
        ]))

        #expect(task.sortedSubtasks.map(\.title) == ["Коробки", "Грузчики"])
        #expect(task.sortedSubtasks.map(\.sortOrder) == [0, 1])
        #expect(task.subtaskProgressText == "1/2")
        #expect(try context.fetchCount(FetchDescriptor<TaskSubtask>()) == 2)
    }

    // Изменение: по uuid текст и отметка обновляются, убранные удаляются, новые добавляются, порядок — как в форме.
    @Test func изменение_обновляетУдаляетДобавляет() throws {
        let task = service.create(from: form([SubtaskDraft(title: "A"), SubtaskDraft(title: "B"), SubtaskDraft(title: "C")]))
        var drafts = TaskSubtaskRules.drafts(of: task)
        let keptID = drafts[2].id
        drafts.remove(at: 1)
        drafts[0].title = "A2"
        drafts[1].isDone = true
        drafts.insert(SubtaskDraft(title: "D"), at: 0)

        service.update(task, from: form(drafts))

        #expect(task.sortedSubtasks.map(\.title) == ["D", "A2", "C"])
        #expect(task.sortedSubtasks.last?.uuid == keptID)
        #expect(task.sortedSubtasks.last?.isDone == true)
        #expect(try context.fetchCount(FetchDescriptor<TaskSubtask>()) == 3)
    }

    // Форма без подзадач (черновик LLM, демо-данные) их не трогает; все отмеченные — задача не закрывается.
    @Test func безСпискаПодзадач_неТрогаетИНеЗакрываетЗадачу() {
        let task = service.create(from: form([SubtaskDraft(title: "A", isDone: true), SubtaskDraft(title: "B", isDone: true)]))

        service.update(task, from: form(nil))

        #expect(task.subtasks.count == 2)
        #expect(task.status == .new)
        #expect(!task.isCompleted)
    }

    // Новая пустая строка в форме — не изменение; отметка подзадачи — изменение.
    @Test func снимокФормы_пустаяСтрокаНеИзменение() {
        let task = service.create(from: form([SubtaskDraft(title: "A")]))
        let initial = TaskFormSnapshot(task: task)
        var drafts = TaskSubtaskRules.drafts(of: task)

        #expect(TaskFormSnapshot(subtasks: drafts + [SubtaskDraft(title: " ")]) == TaskFormSnapshot(subtasks: initial.subtasks))
        drafts[0].isDone = true
        #expect(TaskFormSnapshot(subtasks: drafts) != TaskFormSnapshot(subtasks: initial.subtasks))
    }

    // Журнал: одна строка с числами, без текста подзадач; без изменений подзадач строки нет.
    @Test func журнал_строкаСЧислами() throws {
        let task = service.create(from: form([SubtaskDraft(title: "A"), SubtaskDraft(title: "B", isDone: true), SubtaskDraft(title: "C")]))
        var drafts = TaskSubtaskRules.drafts(of: task)
        drafts[0].isDone = true          // отмечено
        drafts[1].isDone = false         // снято
        drafts[1].title = "B2"           // изменено
        drafts.remove(at: 2)             // −1
        drafts += [SubtaskDraft(title: "D"), SubtaskDraft(title: "E")] // +2

        service.update(task, from: form(drafts))
        let entry = try #require(log.entries.first)
        #expect(entry.changes == ["Подзадачи: +2, −1, изменено 1, отмечено 1, снято 1"])

        service.update(task, from: form(TaskSubtaskRules.drafts(of: task)))
        #expect(log.entries.first?.id == entry.id)
    }

    // Старые настройки отображения без ключа подзадач читаются с включённым счётчиком.
    @Test func настройкиОтображения_безКлюча_счётчикВключён() throws {
        let json = #"{"showDetails":false,"showDeadline":true,"showPriority":true,"showStatus":true,"showTags":true}"#
        let settings = try JSONDecoder().decode(TaskListDisplaySettings.self, from: Data(json.utf8))
        #expect(settings.showSubtasks)
        #expect(!settings.showDetails)
    }

    // Замена по id: найденная строка меняется, удалённая — список не трогает (крестик у пустой подзадачи
    // в фокусе: поле дописывает текст после удаления строки — раньше падение «Index out of range»).
    @Test func заменаПоId_удалённаяСтрокаНеМеняетСписок() {
        let first = SubtaskDraft(title: "Коробки")
        let second = SubtaskDraft(title: "")
        var edited = first
        edited.title = "Коробки и скотч"

        let updated = TaskSubtaskRules.replacing(edited, in: [first, second])
        #expect(updated.map(\.title) == ["Коробки и скотч", ""])

        let afterRemoval = [first]
        #expect(TaskSubtaskRules.replacing(second, in: afterRemoval) == afterRemoval)
        #expect(TaskSubtaskRules.replacing(second, in: []) == [])
    }
}
