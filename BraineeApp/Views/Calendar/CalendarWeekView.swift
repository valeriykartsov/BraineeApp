//
//  CalendarWeekView.swift
//  BraineeApp
//
//  Календарь: недельная лента дней и список задач выбранного дня.

import SwiftUI
import SwiftData

struct CalendarWeekView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// Активна вкладка «Календарь» — при уходе сбрасываем на сегодня.
    var isActive: Bool = true

    @Query(
        filter: #Predicate<TaskItem> { !$0.isSoftDeleted },
        sort: [SortDescriptor(\TaskItem.sortOrder)]
    )
    private var tasks: [TaskItem]

    @State private var weekStart = CalendarWeekHelper.startOfWeek(containing: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: TaskItem?
    @State private var displaySettings = TaskListDisplaySettings.load()

    private var weekDays: [Date] {
        CalendarWeekHelper.daysInWeek(starting: weekStart)
    }

    private var tasksForSelectedDay: [TaskItem] {
        let calendar = Calendar.current
        return tasks
            .filter { task in
                guard let deadline = task.deadline else { return false }
                return calendar.isDate(deadline, inSameDayAs: selectedDay)
            }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted && rhs.isCompleted }
                return (lhs.deadline ?? .distantFuture) < (rhs.deadline ?? .distantFuture)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Календарь")
                    .font(DesignSystem.Typography.title(24))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.top, DesignSystem.Space.x1)
                    .padding(.bottom, DesignSystem.Space.x2)

                weekHeader
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.bottom, DesignSystem.Space.x2)

                weekStrip
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.bottom, DesignSystem.Space.x3)

                dayTasksList
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .tint(DesignSystem.Colors.accent)
            .sheet(item: $editingTask) { task in
                AddEditTaskView(
                    task: task,
                    onSave: { formData in
                        updateTask(task, formData: formData)
                    },
                    onDelete: { taskToDelete in
                        softDelete(taskToDelete)
                        editingTask = nil
                    }
                )
                .id(task.uuid)
            }
            .onAppear {
                displaySettings = TaskListDisplaySettings.load()
                resetToToday()
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    resetToToday()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    resetToToday()
                }
            }
        }
    }

    private func resetToToday() {
        selectedDay = Calendar.current.startOfDay(for: .now)
        weekStart = CalendarWeekHelper.startOfWeek(containing: selectedDay)
    }

    private var weekHeader: some View {
        HStack {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Предыдущая неделя")

            Spacer()

            Text(CalendarWeekHelper.weekRangeTitle(weekStart: weekStart))
                .font(DesignSystem.Typography.headline(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: DesignSystem.Space.x10, height: DesignSystem.Space.x10)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Следующая неделя")
        }
    }

    private var weekStrip: some View {
        HStack(spacing: DesignSystem.Space.x1) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let isToday = Calendar.current.isDateInToday(day)
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: DesignSystem.Space.x1) {
                        Text(CalendarWeekHelper.weekdayShort(day))
                            .font(DesignSystem.Typography.caption(11))
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(DesignSystem.Typography.headline(15))
                    }
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isToday ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Space.x2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.surface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var dayTasksList: some View {
        if tasksForSelectedDay.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                GroupedSection(title: "Задачи дня") {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                        Text("На этот день задач нет")
                            .font(DesignSystem.Typography.headline())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("Создайте задачу с дедлайном на выбранную дату в разделе «Задачи».")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Space.x4)
                }
            }
            .groupedScreenPadding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                GroupedSection(title: "Задачи дня") {
                    VStack(spacing: 0) {
                        ForEach(Array(tasksForSelectedDay.enumerated()), id: \.element.uuid) { index, task in
                            TaskRowView(
                                task: task,
                                displaySettings: displaySettings,
                                showsActionButtons: true,
                                onToggle: { toggleTask(task) },
                                onEdit: { editingTask = task },
                                onDelete: { softDelete(task) }
                            )
                            .padding(.horizontal, DesignSystem.Space.x3)
                            .padding(.vertical, DesignSystem.Space.x2)
                            .contentShape(Rectangle())
                            .onTapGesture { editingTask = task }
                            .contextMenu {
                                Button("Редактировать") { editingTask = task }
                                Button("Удалить", role: .destructive) { softDelete(task) }
                            }
                            if index < tasksForSelectedDay.count - 1 {
                                InsetDivider(leading: DesignSystem.Space.rowIconInset)
                            }
                        }
                    }
                }
                .groupedScreenPadding()
                .padding(.vertical, DesignSystem.Space.x2 + 2)
            }
        }
    }

    private func shiftWeek(by weeks: Int) {
        let calendar = Calendar.current
        let dayOffset = calendar.dateComponents([.day], from: weekStart, to: selectedDay).day ?? 0
        guard let next = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) else { return }
        weekStart = next
        selectedDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
    }

    private var taskService: TaskService {
        TaskService(context: modelContext)
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            taskService.toggleCompletion(task)
        }
        if task.isCompleted {
            HapticFeedback.success()
        }
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        taskService.update(task, from: formData)
    }

    private func softDelete(_ task: TaskItem) {
        withAnimation {
            taskService.softDelete(task)
        }
    }
}

#Preview {
    CalendarWeekView()
        .modelContainer(for: [TaskItem.self, TaskGroup.self, TaskTag.self], inMemory: true)
}
