//
//  DemoDataSeeder.swift
//  BraineeApp
//
//  Только отладочная сборка, аргумент запуска `-SeedDemoData`: заполняет ПУСТОЕ хранилище
//  демо-задачами, папками, тегами и привычками для скриншотов и ручной проверки.
//  Если в хранилище уже есть задачи, привычки или папки — ничего не делает.
//  Данные создаются через сервисы Domain/, как из интерфейса.

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    static let launchArgument = "-SeedDemoData"

    static func seedIfRequested(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        let isEmpty = context.fetchActiveTasks().isEmpty
            && context.fetchHabits().isEmpty
            && ((try? context.fetchCount(FetchDescriptor<TaskGroup>())) ?? 0) == 0
        guard isEmpty else { return }

        // Сохранение, виджет и уведомления — один раз в конце.
        let silent: (ModelContext) -> Void = { _ in }
        let tasks = TaskService(context: context, onChange: silent)
        let groups = GroupService(context: context, onChange: silent)
        let tags = TagService(context: context, onChange: silent)
        let habits = HabitService(context: context, onChange: silent)

        let work = groups.create(name: "Работа")
        let home = groups.create(name: "Дом")
        let calls = tags.create(name: "Звонки")
        let health = tags.create(name: "Здоровье")

        func day(_ offset: Int, _ hour: Int? = nil) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            guard let hour else { return base }
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }

        @discardableResult
        func task(
            _ title: String,
            details: String = "",
            deadline: Date? = nil,
            withTime: Bool = false,
            priority: TaskPriority = .medium,
            tags taskTags: [TaskTag?] = [],
            group: TaskGroup? = nil,
            done: Bool = false
        ) -> TaskItem {
            let item = tasks.create(from: TaskFormData(
                title: title,
                deadline: deadline,
                hasDeadlineTime: withTime,
                reminderOffsets: [],
                priority: priority,
                status: .new,
                taskDetails: details,
                selectedTags: taskTags.compactMap { $0 }
            ))
            if let group { tasks.move(item, to: group) }
            if done { tasks.toggleCompletion(item) }
            return item
        }

        task("Подготовить отчёт за квартал", details: "Цифры продаж и выводы для команды",
             deadline: day(0, 15), withTime: true, priority: .high, group: work)
        task("Созвон с командой", deadline: day(0, 11), withTime: true, tags: [calls], group: work)
        task("Отправить счёт клиенту", deadline: day(-1), priority: .high, group: work, done: true)
        task("Оплатить коммуналку", deadline: day(-1), priority: .high, group: home)
        task("Купить продукты", details: "Молоко, хлеб, овощи", deadline: day(0), priority: .low, group: home)
        task("Позвонить в банк", deadline: day(1, 10), withTime: true, priority: .highest, tags: [calls])
        task("Записаться к стоматологу", deadline: day(3), tags: [calls, health])
        task("Пробежка 5 км", deadline: day(0), tags: [health], done: true)
        task("Прочитать главу книги", priority: .low)

        // Отметки привычек — за последние 14 дней (столько разрешает интерфейс).
        let pattern: [(String, [Int])] = [
            ("Зарядка", [0, 1, 2, 3, 5, 6, 7, 9, 10, 12, 13]),
            ("Чтение 20 минут", [0, 1, 3, 4, 6, 8, 11, 13]),
            ("Вода 2 литра", [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]),
            ("Без сахара", [2, 4, 7, 9]),
        ]
        for (title, daysAgo) in pattern {
            guard let habit = habits.create(title: title) else { continue }
            for offset in daysAgo {
                habits.toggle(habit, on: day(-offset), now: now, calendar: calendar)
            }
        }

        ProfileService(context: context, onChange: silent)
            .update(name: "Алекс", age: nil, gender: .unspecified, avatarData: nil)

        // Все вкладки на панели — для обзорных скриншотов.
        TabBarSettings(showCalendar: true, showLLM: true, showHabits: true).save()

        context.didChange()
    }
}
#endif
