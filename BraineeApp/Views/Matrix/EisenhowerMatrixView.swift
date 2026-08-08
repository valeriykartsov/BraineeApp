//
//  EisenhowerMatrixView.swift
//  BraineeApp
//
//  Матрица Эйзенхауэра: 4 квадранта по срочности дедлайна и приоритету.

import SwiftUI
import SwiftData

struct EisenhowerMatrixView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { !$0.isSoftDeleted },
        sort: [SortDescriptor(\TaskItem.sortOrder)]
    )
    private var tasks: [TaskItem]

    @State private var editingTask: TaskItem?

    private var tasksByQuadrant: [EisenhowerQuadrant: [TaskItem]] {
        var result: [EisenhowerQuadrant: [TaskItem]] = Dictionary(
            uniqueKeysWithValues: EisenhowerQuadrant.allCases.map { ($0, []) }
        )
        for task in tasks {
            let quadrant = EisenhowerQuadrant.classify(task)
            result[quadrant, default: []].append(task)
        }
        for key in result.keys {
            result[key]?.sort { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted && rhs.isCompleted }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Матрица")
                    .font(DesignSystem.Typography.title(24))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.top, DesignSystem.Space.x1)
                    .padding(.bottom, DesignSystem.Space.x2)

                ScrollView {
                    VStack(spacing: DesignSystem.Space.x2) {
                        HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                            quadrantCard(.doFirst)
                            quadrantCard(.schedule)
                        }
                        HStack(alignment: .top, spacing: DesignSystem.Space.x2) {
                            quadrantCard(.delegate)
                            quadrantCard(.eliminate)
                        }
                    }
                    .groupedScreenPadding()
                    .padding(.top, DesignSystem.Space.x2)
                    .padding(.bottom, DesignSystem.Space.x4)
                }
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
            }
        }
    }

    private func quadrantCard(_ quadrant: EisenhowerQuadrant) -> some View {
        let items = tasksByQuadrant[quadrant] ?? []
        let shape = RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)

        return VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                Text(quadrant.title)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(quadrant.subtitle)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            if items.isEmpty {
                Text("Пусто")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Space.x1)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x1 + 1) {
                    ForEach(items, id: \.uuid) { task in
                        Button {
                            editingTask = task
                        } label: {
                            Text(task.title)
                                .font(DesignSystem.Typography.bodyBold(15))
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(
                                    task.isCompleted
                                        ? DesignSystem.Colors.textSecondary
                                        : DesignSystem.Colors.textPrimary
                                )
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DesignSystem.Space.x3)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(shape.fill(DesignSystem.Colors.surface))
    }

    private func updateTask(_ task: TaskItem, formData: TaskFormData) {
        task.title = formData.title
        task.deadline = formData.deadline
        task.hasDeadlineTime = formData.hasDeadlineTime
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

#Preview {
    EisenhowerMatrixView()
        .modelContainer(for: [TaskItem.self], inMemory: true)
}
