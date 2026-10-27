//
//  TaskRowView.swift
//  BraineeApp
//
//  Карточка задачи — одна для списка, канбана, «Календаря» и матрицы (п. 37):
//  чекбокс, название в 1 строку, описание до 2 строк, метки с переносом строк (`TaskCardMeta`),
//  «корзина» с подтверждением. Нажатие на карточку открывает форму; меню и свайпа нет.
//  Просроченные подсвечиваются бледно-красным фоном того же размера, что и карточка.
//  Текущее время для просрочки — одно на экран (`.taskRowClock()`), а не таймер в каждой строке (п. 10).

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var displaySettings: TaskListDisplaySettings = .default
    /// Фон отдельной карточки (канбан). Без него карточка — строка в общем контейнере экрана.
    var cardFill: Color? = nil
    var onToggle: () -> Void
    var onOpen: () -> Void
    /// Удаление в корзину; вызывается только после подтверждения.
    var onDelete: (() -> Void)? = nil

    /// Над картинкой со «Стеклом» подложки карточки прозрачнее — по тому же ползунку (п. 60).
    @Environment(\.appGlass) private var glass

    /// Время от `.taskRowClock()` экрана; без него — момент отрисовки.
    @Environment(\.taskRowNow) private var clockNow
    @State private var showingDeleteConfirm = false

    var body: some View {
        let now = clockNow ?? .now
        let overdue = !task.isCompleted && task.isOverdue(at: now)
        let meta = TaskCardMeta(task: task, settings: displaySettings, overdue: overdue)
        HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.accent
                            : (overdue ? DesignSystem.Colors.danger : DesignSystem.Colors.textSecondary)
                    )
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .accessibilityLabel(task.isCompleted ? "Снять выполнение" : "Отметить выполненной")

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                Text(task.title)
                    .font(DesignSystem.Typography.body(16))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.textPrimary
                    )
                    .lineLimit(1)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Открыть задачу")
                    .accessibilityAction { onOpen() }

                if displaySettings.showDetails, !task.taskDetails.isEmpty {
                    Text(task.taskDetails)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                if !meta.chips.isEmpty {
                    metaChips(meta.chips)
                }
            }
            // Вся ширина до «корзины» — меткам (без Spacer: он делил бы место с потоком меток,
            // и метки переносились бы раньше времени).
            .frame(maxWidth: .infinity, alignment: .leading)

            if onDelete != nil {
                IconTapButton(
                    systemName: DesignSystem.Icon.trash,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Удалить задачу"
                ) {
                    showingDeleteConfirm = true
                }
                .padding(.top, -2)
            }
        }
        .opacity(task.isCompleted ? 0.55 : 1)
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { background(overdue: overdue) }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .alert("Удалить задачу?", isPresented: $showingDeleteConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Задача будет перемещена в «Удалённые задачи» в профиле.")
        }
    }

    /// Отдельная карточка красится целиком. Строка в общем контейнере — подложкой
    /// с небольшим отступом от краёв, чтобы не перекрывать скруглённые углы контейнера.
    @ViewBuilder
    private func background(overdue: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
        if let cardFill {
            shape.fill((overdue ? DesignSystem.Colors.dangerSoft : cardFill).opacity(glass.cardFillOpacity))
        } else if overdue {
            shape
                .fill(DesignSystem.Colors.dangerSoft.opacity(glass.cardFillOpacity))
                .padding(.horizontal, DesignSystem.Space.x1)
                .padding(.vertical, 2)
        }
    }

    /// Метки одним потоком: не поместившаяся переносится на следующую строку (без своей
    /// горизонтальной прокрутки — UIScrollView в каждой строке утяжелял список, п. 10).
    private func metaChips(_ chips: [TaskCardMeta.Chip]) -> some View {
        TagFlowLayout(spacing: DesignSystem.Space.x1) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                metaChip(chip)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaChip(_ chip: TaskCardMeta.Chip) -> MetaChip {
        switch chip {
        case let .deadline(text, overdue):
            return MetaChip(
                text: text,
                foreground: overdue
                    ? DesignSystem.Colors.danger
                    : DesignSystem.Colors.textSecondary,
                background: overdue
                    ? DesignSystem.Colors.danger.opacity(0.12)
                    : DesignSystem.Colors.chip
            )
        case let .status(status):
            return MetaChip(text: status.title, foreground: DesignSystem.Colors.accent)
        case let .subtasks(text):
            return MetaChip(text: text, foreground: DesignSystem.Colors.textSecondary)
        case let .priority(priority):
            return MetaChip(text: priority.title, foreground: PriorityStyle.color(for: priority))
        case let .tag(name):
            return MetaChip(text: name, foreground: DesignSystem.Colors.textSecondary)
        }
    }
}

/// Общие часы строк задач: раз в 30 с обновляют «сейчас» для всех строк экрана сразу.
private struct TaskRowNowKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    var taskRowNow: Date? {
        get { self[TaskRowNowKey.self] }
        set { self[TaskRowNowKey.self] = newValue }
    }
}

private struct TaskRowClock: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content.environment(\.taskRowNow, context.date)
        }
    }
}

extension View {
    /// Один таймер на экран со строками задач — чтобы просрочка обновлялась без таймера в каждой строке.
    func taskRowClock() -> some View {
        modifier(TaskRowClock())
    }
}

/// Чип meta-поля на серой подложке — как теги в других разделах.
private struct MetaChip: View {
    let text: String
    let foreground: Color
    var background: Color = DesignSystem.Colors.chip

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption(12))
            .fontWeight(.medium)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, DesignSystem.Space.x2)
            .padding(.vertical, DesignSystem.Space.x1)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }
}

#Preview {
    GroupedCard {
        TaskRowView(
            task: TaskItem(
                title: "Подготовить презентацию",
                deadline: Calendar.current.date(byAdding: .day, value: -1, to: .now),
                hasDeadlineTime: true,
                priority: .highest,
                taskDetails: "Слайды и тезисы"
            ),
            onToggle: {},
            onOpen: {},
            onDelete: {}
        )
    }
    .padding(DesignSystem.Space.x4)
    .appScreenBackground()
    .modelContainer(for: TaskItem.self, inMemory: true)
}
