//
//  HabitsView.swift
//  BraineeApp
//
//  Привычки: contribution-календарь, прогресс за день, список до 7 штук.
//  День отметок можно листать назад до 14 суток.

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.sortOrder)])
    private var habits: [Habit]

    @State private var showingAdd = false
    @State private var editingHabit: Habit?
    @State private var habitPendingDeletion: Habit?
    @State private var showingDeleteConfirm = false
    @State private var draggingUUID: UUID?
    /// День, за который отмечаем привычки и считаем прогресс (сегодня…−14).
    @State private var selectedDay = HabitDaySelection.startOfDay(.now)
    @State private var isLimitsHintExpanded = false
    @Namespace private var habitReorderNamespace

    private var selectedDayProgress: Double {
        HabitProgress.completionRatio(for: selectedDay, habits: habits)
    }

    private var canAddMore: Bool {
        habits.count < Habit.maxCount
    }

    private var springAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.82)
    }

    private var canGoToPreviousDay: Bool {
        HabitDaySelection.canMoveBack(selectedDay)
    }

    private var canGoToNextDay: Bool {
        HabitDaySelection.canMoveForward(selectedDay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Привычки")
                        .font(DesignSystem.Typography.title(24))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                            .contentShape(Rectangle())
                    }
                    .disabled(!canAddMore)
                    .opacity(canAddMore ? 1 : 0.35)
                    .accessibilityLabel("Добавить привычку")
                }
                .padding(.horizontal, DesignSystem.Space.screenInset)
                .padding(.top, DesignSystem.Space.x1)
                .padding(.bottom, DesignSystem.Space.x2)

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.sectionGap) {
                        progressSection
                        habitsListSection
                    }
                    .groupedScreenPadding()
                    .padding(.top, DesignSystem.Space.x2)
                    .padding(.bottom, DesignSystem.Space.x4)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .tint(DesignSystem.Colors.accent)
            .sheet(isPresented: $showingAdd) {
                AddEditHabitView { title in
                    addHabit(title: title)
                }
            }
            .sheet(item: $editingHabit) { habit in
                AddEditHabitView(
                    habit: habit,
                    onSave: { title in
                        habit.title = title
                        modelContext.persistToJSON()
                    },
                    onDelete: {
                        // Подтверждение уже в форме; удаляем после «Удалить».
                        deleteHabit(habit)
                    }
                )
            }
            .alert("Удалить привычку?", isPresented: $showingDeleteConfirm) {
                Button("Отмена", role: .cancel) {
                    habitPendingDeletion = nil
                }
                Button("Удалить", role: .destructive) {
                    if let habit = habitPendingDeletion {
                        deleteHabit(habit)
                    }
                    habitPendingDeletion = nil
                }
            } message: {
                Text("История отметок этой привычки будет удалена.")
            }
            .onAppear {
                selectedDay = HabitDaySelection.clamp(selectedDay)
            }
        }
    }

    private var progressSection: some View {
        GroupedSection(title: "Прогресс") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                HabitContributionCalendar(habits: habits, selectedDay: selectedDay)
                    .padding(.top, DesignSystem.Space.x1)

                VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                    HStack {
                        Text(HabitDaySelection.title(for: selectedDay))
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(selectedDayProgressLabel)
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    AppProgressBar(value: selectedDayProgress)
                }

                limitsHint

                daySwitcher
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x3)
        }
    }

    private var limitsHint: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLimitsHintExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Space.x2) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text("Подсказка по ограничениям")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer(minLength: DesignSystem.Space.x2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.8))
                        .rotationEffect(.degrees(isLimitsHintExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Подсказка по ограничениям")
            .accessibilityHint(isLimitsHintExpanded ? "Свернуть" : "Развернуть")

            if isLimitsHintExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                    Text("• Не больше \(Habit.maxCount) привычек.")
                    Text("• Отметки можно ставить и менять за сегодня и \(HabitDaySelection.maxDaysBack) предыдущих дней.")
                    Text("• Будущие дни недоступны для отметок.")
                    Text("• Данные хранятся только на этом устройстве.")
                }
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, DesignSystem.Space.x2)
        .padding(.vertical, DesignSystem.Space.x2)
        .background(DesignSystem.Colors.chip.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }

    private var daySwitcher: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Button {
                selectedDay = HabitDaySelection.shifting(selectedDay, by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        canGoToPreviousDay
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary.opacity(0.35)
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoToPreviousDay)
            .accessibilityLabel("Предыдущий день")

            Text(HabitDaySelection.title(for: selectedDay))
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Выбранный день")

            Button {
                selectedDay = HabitDaySelection.shifting(selectedDay, by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        canGoToNextDay
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary.opacity(0.35)
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoToNextDay)
            .accessibilityLabel("Следующий день")
        }
        .padding(.horizontal, DesignSystem.Space.x1)
        .padding(.vertical, DesignSystem.Space.x1)
        .background(DesignSystem.Colors.chip.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous))
    }

    private var selectedDayProgressLabel: String {
        guard !habits.isEmpty else { return "0%" }
        let percent = Int((selectedDayProgress * 100).rounded())
        return "\(percent)%"
    }

    @ViewBuilder
    private var habitsListSection: some View {
        GroupedSection(title: "Список") {
            if habits.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                    Text("Пока нет привычек")
                        .font(DesignSystem.Typography.headline())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Добавьте до \(Habit.maxCount) привычек и отмечайте их каждый день.")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Space.x4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.uuid) { index, habit in
                        habitRow(habit)
                            .matchedGeometryEffect(id: habit.uuid, in: habitReorderNamespace)
                        if index < habits.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.rowIconInset)
                        }
                    }
                }
                .animation(springAnimation, value: habits.map(\.uuid))
                .animation(springAnimation, value: Habit.dayKey(for: selectedDay))
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let doneOnSelectedDay = habit.isCompleted(on: selectedDay)
        let isDragging = draggingUUID == habit.uuid

        return HStack(spacing: DesignSystem.Space.x2) {
            Button {
                toggleHabit(habit)
            } label: {
                Image(systemName: doneOnSelectedDay ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(
                        doneOnSelectedDay
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                doneOnSelectedDay
                    ? "Снять отметку за \(HabitDaySelection.title(for: selectedDay))"
                    : "Отметить за \(HabitDaySelection.title(for: selectedDay))"
            )

            Text(habit.title)
                .font(DesignSystem.Typography.body(16))
                .strikethrough(doneOnSelectedDay)
                .foregroundStyle(
                    doneOnSelectedDay
                        ? DesignSystem.Colors.textSecondary
                        : DesignSystem.Colors.textPrimary
                )
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingHabit = habit
                }

            HStack(spacing: 0) {
                IconTapButton(
                    systemName: DesignSystem.Icon.pencil,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Редактировать привычку"
                ) {
                    editingHabit = habit
                }
                IconTapButton(
                    systemName: DesignSystem.Icon.trash,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Удалить привычку"
                ) {
                    requestDelete(habit)
                }
            }

            HabitDragHandle(
                habitUUID: habit.uuid,
                onLift: { draggingUUID = habit.uuid },
                onEnded: {
                    draggingUUID = nil
                    modelContext.persistToJSON()
                }
            ) {
                habitDragPreview(habit)
            }
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2)
        .scaleEffect(isDragging ? 1.03 : 1)
        .opacity(isDragging ? 0.92 : 1)
        .zIndex(isDragging ? 1 : 0)
        .dropDestination(for: String.self) { _, _ in
            draggingUUID = nil
            modelContext.persistToJSON()
            return true
        } isTargeted: { hovering in
            guard hovering, let draggingUUID, draggingUUID != habit.uuid else { return }
            withAnimation(springAnimation) {
                liveReorder(draggedID: draggingUUID, onto: habit.uuid)
            }
        }
    }

    private func habitDragPreview(_ habit: Habit) -> some View {
        Text(habit.title)
            .font(DesignSystem.Typography.body(16))
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
            .frame(width: 280, alignment: .leading)
            .background(DesignSystem.Colors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private func requestDelete(_ habit: Habit) {
        habitPendingDeletion = habit
        showingDeleteConfirm = true
    }

    private func toggleHabit(_ habit: Habit) {
        let day = HabitDaySelection.clamp(selectedDay)
        withAnimation {
            habit.toggleCompletion(on: day)
        }
        if habit.isCompleted(on: day) {
            HapticFeedback.success()
        }
        modelContext.persistToJSON()
    }

    private func addHabit(title: String) {
        guard canAddMore, TaskInputValidation.canSaveTitle(title) else { return }
        let nextOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(title: title, sortOrder: nextOrder)
        modelContext.insert(habit)
        modelContext.persistToJSON()
    }

    private func deleteHabit(_ habit: Habit) {
        withAnimation {
            modelContext.delete(habit)
        }
        modelContext.persistToJSON()
        if editingHabit?.uuid == habit.uuid {
            editingHabit = nil
        }
    }

    /// Живое вытеснение: при наведении на другую строку порядок обновляется сразу.
    private func liveReorder(draggedID: UUID, onto targetID: UUID) {
        var ordered = habits
        guard let fromIndex = ordered.firstIndex(where: { $0.uuid == draggedID }),
              let toIndex = ordered.firstIndex(where: { $0.uuid == targetID }),
              fromIndex != toIndex else {
            return
        }
        ordered.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
        for (index, habit) in ordered.enumerated() {
            habit.sortOrder = index
        }
    }
}

/// Ручка drag: lift + колбэки для анимации вытеснения.
private struct HabitDragHandle<Preview: View>: View {
    let habitUUID: UUID
    var onLift: () -> Void
    var onEnded: () -> Void
    @ViewBuilder var preview: () -> Preview
    @GestureState private var isLiftSelected = false

    var body: some View {
        Image(systemName: DesignSystem.Icon.drag)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.75))
            .frame(width: 32, height: DesignSystem.Space.x11)
            .contentShape(Rectangle())
            .accessibilityLabel("Перетащить привычку")
            .draggable(habitUUID.uuidString, preview: preview)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .updating($isLiftSelected) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
            )
            .onChange(of: isLiftSelected) { _, selected in
                if selected {
                    HapticFeedback.lift()
                    onLift()
                } else {
                    onEnded()
                }
            }
    }
}

#Preview {
    HabitsView()
        .modelContainer(for: Habit.self, inMemory: true)
}
