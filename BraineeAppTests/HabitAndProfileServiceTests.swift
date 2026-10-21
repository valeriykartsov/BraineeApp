//
//  HabitAndProfileServiceTests.swift
//  BraineeAppTests
//
//  HabitService и ProfileService (roadmap DOM-2b).
//  onChange подменён счётчиком — тесты не пишут настоящие JSON, Keychain и уведомления.

import Foundation
import Testing
import SwiftData
@testable import BraineeApp

@MainActor
struct HabitAndProfileServiceTests {
    /// Контейнер живёт столько же, сколько тест (см. TaskServiceTests).
    private let container: ModelContainer

    init() throws {
        container = try TestHelpers.makeContainer()
    }

    private final class ChangeCounter {
        var count = 0
    }

    private func habits(_ counter: ChangeCounter) -> HabitService {
        HabitService(context: container.mainContext, onChange: { _ in counter.count += 1 })
    }

    private func profile(_ counter: ChangeCounter) -> ProfileService {
        ProfileService(context: container.mainContext, onChange: { _ in counter.count += 1 })
    }

    /// Фиксированные «сегодня» и календарь, чтобы тесты не зависели от даты запуска.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let today = Date(timeIntervalSince1970: 1_761_000_000) // 2025-10-20 UTC

    // MARK: - Привычки: создание и переименование

    // Новая привычка: название без пробелов по краям, в конце списка.
    @Test func созданиеПривычки_вКонецСписка() throws {
        container.mainContext.insert(Habit(title: "Первая", sortOrder: 4))
        let counter = ChangeCounter()

        let habit = try #require(habits(counter).create(title: "  Спорт "))

        #expect(habit.title == "Спорт")
        #expect(habit.sortOrder == 5)
        #expect(counter.count == 1)
    }

    // Больше Habit.maxCount привычек создать нельзя.
    @Test func созданиеПривычки_неБольшеМаксимума() throws {
        for index in 0..<Habit.maxCount {
            container.mainContext.insert(Habit(title: "П\(index)", sortOrder: index))
        }
        let counter = ChangeCounter()
        let service = habits(counter)

        #expect(!service.canAddMore)
        #expect(service.create(title: "Лишняя") == nil)
        #expect(service.habits.count == Habit.maxCount)
        #expect(counter.count == 0)
    }

    // Пустое название не создаёт и не переименовывает привычку.
    @Test func пустоеНазвание_отклоняется() throws {
        let habit = Habit(title: "Чтение")
        container.mainContext.insert(habit)
        let counter = ChangeCounter()
        let service = habits(counter)

        #expect(service.create(title: "   ") == nil)
        #expect(service.rename(habit, to: "  ") == false)
        #expect(habit.title == "Чтение")
        #expect(service.rename(habit, to: " Книги ") == true)
        #expect(habit.title == "Книги")
        #expect(counter.count == 1)
    }

    // MARK: - Привычки: отметка дня

    // Отметка за сегодня: включается, повторное нажатие снимает.
    @Test func отметкаСегодня_включаетсяИСнимается() throws {
        let habit = Habit(title: "Спорт")
        container.mainContext.insert(habit)
        let counter = ChangeCounter()
        let service = habits(counter)

        #expect(service.toggle(habit, on: today, now: today, calendar: calendar) == true)
        #expect(habit.isCompleted(on: today, calendar: calendar))
        #expect(service.toggle(habit, on: today, now: today, calendar: calendar) == false)
        #expect(!habit.isCompleted(on: today, calendar: calendar))
        #expect(counter.count == 2)
    }

    // День в будущем приводится к сегодняшнему (правило HabitDaySelection.clamp).
    @Test func отметкаБудущегоДня_ставитсяНаСегодня() throws {
        let habit = Habit(title: "Спорт")
        container.mainContext.insert(habit)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))

        habits(ChangeCounter()).toggle(habit, on: tomorrow, now: today, calendar: calendar)

        #expect(habit.isCompleted(on: today, calendar: calendar))
        #expect(!habit.isCompleted(on: tomorrow, calendar: calendar))
    }

    // День раньше разрешённого окна приводится к самому раннему допустимому дню.
    @Test func отметкаСлишкомСтарогоДня_ставитсяНаРаннийДопустимый() throws {
        let habit = Habit(title: "Спорт")
        container.mainContext.insert(habit)
        let longAgo = try #require(calendar.date(byAdding: .day, value: -100, to: today))
        let earliest = HabitDaySelection.earliestAllowed(relativeTo: today, calendar: calendar)

        habits(ChangeCounter()).toggle(habit, on: longAgo, now: today, calendar: calendar)

        #expect(habit.isCompleted(on: earliest, calendar: calendar))
        #expect(!habit.isCompleted(on: longAgo, calendar: calendar))
    }

    // MARK: - Привычки: удаление и порядок

    // Удаление убирает привычку вместе с её отметками.
    @Test func удалениеПривычки() throws {
        let habit = Habit(title: "Спорт", completedDayKeys: ["2025-10-19"])
        container.mainContext.insert(habit)
        let counter = ChangeCounter()
        let service = habits(counter)

        service.delete(habit)

        #expect(service.habits.isEmpty)
        #expect(counter.count == 1)
    }

    // Перетаскивание вниз и вверх даёт сплошной порядок 0…n без сохранения; saveOrder сохраняет один раз.
    @Test func перестановка_меняетПорядокСохранениеОтдельно() throws {
        let context = container.mainContext
        let first = Habit(title: "A", sortOrder: 0)
        let second = Habit(title: "B", sortOrder: 1)
        let third = Habit(title: "C", sortOrder: 2)
        for habit in [first, second, third] { context.insert(habit) }
        let counter = ChangeCounter()
        let service = habits(counter)

        service.move(first.uuid, onto: third.uuid)
        #expect(service.habits.map(\.title) == ["B", "C", "A"])
        service.move(first.uuid, onto: second.uuid)
        #expect(service.habits.map(\.title) == ["A", "B", "C"])
        #expect(service.habits.map(\.sortOrder) == [0, 1, 2])
        #expect(counter.count == 0)

        service.saveOrder()
        #expect(counter.count == 1)
    }

    // Перетаскивание на саму себя или на неизвестную привычку ничего не меняет.
    @Test func перестановкаНаСебя_ничегоНеМеняет() throws {
        let habit = Habit(title: "A", sortOrder: 7)
        container.mainContext.insert(habit)
        let service = habits(ChangeCounter())

        service.move(habit.uuid, onto: habit.uuid)
        service.move(habit.uuid, onto: UUID())

        #expect(habit.sortOrder == 7)
    }

    // Отпускание на строке переставляет по данным перетаскивания, даже без перестановки при наведении (п. 6).
    @Test func отпусканиеНаСтроке_переставляетИСохраняетОдинРаз() throws {
        let context = container.mainContext
        let first = Habit(title: "A", sortOrder: 0)
        let second = Habit(title: "B", sortOrder: 1)
        let third = Habit(title: "C", sortOrder: 2)
        for habit in [first, second, third] { context.insert(habit) }
        let counter = ChangeCounter()
        let service = habits(counter)

        service.finishDrag(payload: [first.uuid.uuidString], onto: third.uuid)

        #expect(service.habits.map(\.title) == ["B", "C", "A"])
        #expect(service.habits.map(\.sortOrder) == [0, 1, 2])
        #expect(counter.count == 1)
    }

    // Отпускание мимо строк или с чужими данными порядок не меняет, но уже переставленное сохраняет.
    @Test func отпусканиеМимоСтрок_толькоСохраняет() throws {
        let context = container.mainContext
        let first = Habit(title: "A", sortOrder: 0)
        let second = Habit(title: "B", sortOrder: 1)
        for habit in [first, second] { context.insert(habit) }
        let counter = ChangeCounter()
        let service = habits(counter)

        service.finishDrag(payload: [first.uuid.uuidString], onto: nil)
        service.finishDrag(payload: ["не uuid"], onto: second.uuid)

        #expect(service.habits.map(\.title) == ["A", "B"])
        #expect(counter.count == 2)
    }

    // MARK: - Профиль

    // Профиля нет — создаётся один пустой; повторный вызов не создаёт второй.
    @Test func профильНет_создаётсяОдинРаз() throws {
        let counter = ChangeCounter()
        let service = profile(counter)

        let first = service.ensureProfile()
        let second = service.ensureProfile()

        #expect(first.persistentModelID == second.persistentModelID)
        #expect(try container.mainContext.fetch(FetchDescriptor<UserProfile>()).count == 1)
        #expect(counter.count == 1)
    }

    // Обновление профиля меняет все поля существующего профиля.
    @Test func обновлениеПрофиля_меняетПоля() throws {
        let existing = UserProfile(displayName: "Старое")
        container.mainContext.insert(existing)
        let counter = ChangeCounter()
        let avatar = Data([0x01, 0x02])

        profile(counter).update(name: "Валера", age: 33, gender: .male, avatarData: avatar)

        #expect(existing.displayName == "Валера")
        #expect(existing.age == 33)
        #expect(existing.gender == .male)
        #expect(existing.avatarData == avatar)
        #expect(try container.mainContext.fetch(FetchDescriptor<UserProfile>()).count == 1)
        #expect(counter.count == 1)
    }

    // Смена темы/акцента сохраняет профиль (копия в profile.json не отстаёт).
    @Test func сменаОформления_сохраняет() {
        let counter = ChangeCounter()

        profile(counter).appearanceDidChange()

        #expect(counter.count == 1)
    }
}
