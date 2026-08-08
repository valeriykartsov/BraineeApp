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
                            Button {
                                editingTask = task
                            } label: {
                                TaskRowView(task: task, displaySettings: displaySettings) {
                                    toggleTask(task)
                                }
                                .padding(.horizontal, DesignSystem.Space.x3)
                                .padding(.vertical, DesignSystem.Space.x2)
                            }
                            .buttonStyle(.plain)

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

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            task.applyCompletionToggle()
        }
        if task.isCompleted {
            HapticFeedback.success()
        }
        modelContext.persistToJSON()
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        task.title = formData.title
        task.deadline = formData.deadline
        task.hasDeadlineTime = formData.hasDeadlineTime
        task.reminderOffsets = formData.reminderOffsets
        task.priority = formData.priority
        task.status = formData.status
        task.category = .tasks
        task.taskDetails = formData.taskDetails
        task.tags = formData.selectedTags
        modelContext.persistToJSON()
    }

    private func softDelete(_ task: TaskItem) {
        withAnimation {
            task.isSoftDeleted = true
            task.deletedAt = .now
        }
        try? modelContext.save()
        modelContext.persistToJSON()
    }
}
