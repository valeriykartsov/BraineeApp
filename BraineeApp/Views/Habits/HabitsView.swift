//
//  HabitsView.swift
//  BraineeApp
//
//  Привычки: contribution-календарь, прогресс сегодня, список до 7 штук.

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
    @Namespace private var habitReorderNamespace

    private var todayProgress: Double {
        HabitProgress.completionRatio(for: .now, habits: habits)
    }

    private var canAddMore: Bool {
        habits.count < Habit.maxCount
    }

    private var springAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.82)
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
        }
    }

    private var progressSection: some View {
        GroupedSection(title: "Прогресс") {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                HabitContributionCalendar(habits: habits)
                    .padding(.top, DesignSystem.Space.x1)

                VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                    HStack {
                        Text("Сегодня")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(todayProgressLabel)
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    AppProgressBar(value: todayProgress)
                }
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x3)
        }
    }

    private var todayProgressLabel: String {
        guard !habits.isEmpty else { return "0%" }
        let percent = Int((todayProgress * 100).rounded())
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
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let doneToday = habit.isCompleted(on: .now)
        let isDragging = draggingUUID == habit.uuid

        return HStack(spacing: DesignSystem.Space.x2) {
            Button {
                toggleHabit(habit)
            } label: {
                Image(systemName: doneToday ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(
                        doneToday
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
                    .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(habit.title)
                .font(DesignSystem.Typography.body(16))
                .strikethrough(doneToday)
                .foregroundStyle(
                    doneToday
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
                    habitPendingDeletion = habit
                    showingDeleteConfirm = true
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

    private func toggleHabit(_ habit: Habit) {
        withAnimation {
            habit.toggleCompletion(on: .now)
        }
        if habit.isCompleted(on: .now) {
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
