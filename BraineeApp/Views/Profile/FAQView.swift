//
//  FAQView.swift
//  BraineeApp
//
//  Экран FAQ: раскрывающиеся вопросы (открывается из Профиль → Ещё).

import SwiftUI

struct FAQView: View {
    private let items: [FAQItem] = FAQItem.all
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        ScrollView {
            GroupedSection(title: "Вопросы") {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        faqRow(item)
                        if index < items.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.x3)
                        }
                    }
                }
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .appScreenBackground()
        .navigationTitle("FAQ")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func faqRow(_ item: FAQItem) -> some View {
        let isExpanded = expandedIDs.contains(item.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedIDs.remove(item.id)
                    } else {
                        expandedIDs.insert(item.id)
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: DesignSystem.Space.x2) {
                    Text(item.question)
                        .font(DesignSystem.Typography.body(16))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, DesignSystem.Space.x3)
                .padding(.vertical, DesignSystem.Space.x2 + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.x3)
                    .padding(.bottom, DesignSystem.Space.x3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String

    static let all: [FAQItem] = [
        FAQItem(
            id: "what-is-brainee",
            question: "Что такое Brainee?",
            answer: "Brainee — личный органайзер задач: список с папками, канбан по статусам, календарь, матрица Эйзенхауэра и привычки. Данные хранятся на устройстве."
        ),
        FAQItem(
            id: "list-vs-kanban",
            question: "Чем отличаются Список и Канбан?",
            answer: "В Списке задачи собраны по группам (папкам). В Канбане — по статусам «Новая», «В работе» и «Готово»; карточку можно перетащить между колонками."
        ),
        FAQItem(
            id: "new-task-status",
            question: "Какой статус у новой задачи?",
            answer: "При создании задача всегда получает статус «Новая». Статус можно изменить при редактировании или перетащив карточку на канбане. Галочка «выполнено» ставит статус «Готово»."
        ),
        FAQItem(
            id: "deadline-time",
            question: "Как указать время дедлайна?",
            answer: "В карточке задачи включите «Указать дату», затем «Указать время». Если время не выбрано, в списке показывается только дата."
        ),
        FAQItem(
            id: "groups",
            question: "Как работают группы?",
            answer: "Группа — папка для задач в режиме Список. Создайте группу кнопкой с папкой, затем перетащите задачу за ручку справа. Группу можно свернуть, переименовать или удалить (задачи останутся в «Без папки»)."
        ),
        FAQItem(
            id: "soft-delete",
            question: "Куда пропадают удалённые задачи?",
            answer: "Удаление из списка — мягкое: задача попадает в Профиль → Ещё → Удалённые задачи. Оттуда её можно восстановить или удалить навсегда."
        ),
        FAQItem(
            id: "tags",
            question: "Зачем нужна библиотека тегов?",
            answer: "Теги создаются в Профиле и подключаются к задачам. По ним удобно фильтровать смысл задач и смотреть статистику в дашборде."
        ),
        FAQItem(
            id: "tabs",
            question: "Как показать или скрыть Календарь, Матрицу и Привычки?",
            answer: "Откройте Профиль → Ещё → Панель вкладок и включите нужные разделы. Разделы «Задачи» и «Профиль» всегда на месте."
        ),
        FAQItem(
            id: "data-storage",
            question: "Где хранятся данные?",
            answer: "Задачи и профиль сохраняются в JSON-файлах на устройстве и дублируются в Keychain на случай сбоя. iCloud не используется. Путь к папке данных есть в блоке «Хранение» в Профиле."
        ),
        FAQItem(
            id: "completed-order",
            question: "Почему выполненная задача уезжает вниз?",
            answer: "Это сделано специально: отмеченная задача перемещается в конец своей группы (или блока «Без папки»). Если снять галочку, задача встанет в конец списка ещё не закрытых."
        )
    ]
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
