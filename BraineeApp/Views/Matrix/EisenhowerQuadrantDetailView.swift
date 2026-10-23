//
//  EisenhowerQuadrantDetailView.swift
//  BraineeApp
//
//  Список задач выбранного квадранта матрицы Эйзенхауэра.

import SwiftUI
import SwiftData

struct EisenhowerQuadrantDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let quadrant: EisenhowerQuadrant
    let tasks: [TaskItem]

    @State private var editingTask: TaskItem?
    @State private var displaySettings = TaskListDisplaySettings.load()

    var body: some View {
        ScrollView {
            GroupedSection(title: quadrant.subtitle) {
                if tasks.isEmpty {
                    Text("В этом квадранте пока нет задач")
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Space.x4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.uuid) { index, task in
                            TaskRowView(
                                task: task,
                                displaySettings: displaySettings,
                                onToggle: { toggleTask(task) },
                                onOpen: { editingTask = task },
                                onDelete: { softDelete(task) }
                            )

                            if index < tasks.count - 1 {
                                InsetDivider(leading: DesignSystem.Space.rowIconInset)
                            }
                        }
                    }
                }
            }
            .groupedScreenPadding()
            .padding(.top, DesignSystem.Space.x2)
            .padding(.bottom, DesignSystem.Space.x4)
        }
        .taskRowClock()
        .appScreenBackground()
        .navigationTitle(quadrant.title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(DesignSystem.Colors.accent)
        .onAppear {
            displaySettings = TaskListDisplaySettings.load()
        }
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
    }

    private var taskService: TaskService {
        TaskService(context: modelContext)
    }

    /// Теперь, как и в «Задачах»/«Календаре», выполненная задача уходит в конец своей группы.
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
