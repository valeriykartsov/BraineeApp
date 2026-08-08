//
//  EisenhowerMatrixView.swift
//  BraineeApp
//
//  Матрица Эйзенхауэра: 4 одинаковых квадранта; тап открывает список задач.

import SwiftUI
import SwiftData

struct EisenhowerMatrixView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        filter: #Predicate<TaskItem> { !$0.isSoftDeleted },
        sort: [SortDescriptor(\TaskItem.sortOrder)]
    )
    private var tasks: [TaskItem]

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
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: DesignSystem.Space.x2),
                            GridItem(.flexible(), spacing: DesignSystem.Space.x2)
                        ],
                        spacing: DesignSystem.Space.x2
                    ) {
                        ForEach(EisenhowerQuadrant.allCases) { quadrant in
                            NavigationLink(value: quadrant) {
                                quadrantCard(quadrant)
                            }
                            .buttonStyle(.plain)
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
            .navigationDestination(for: EisenhowerQuadrant.self) { quadrant in
                EisenhowerQuadrantDetailView(
                    quadrant: quadrant,
                    tasks: tasksByQuadrant[quadrant] ?? []
                )
            }
        }
    }

    private func quadrantCard(_ quadrant: EisenhowerQuadrant) -> some View {
        let items = tasksByQuadrant[quadrant] ?? []
        let preview = EisenhowerMatrixLayout.preview(items: items)
        let shape = RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
        let showsBorder = colorScheme == .light

        return VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(quadrant.title)
                        .font(DesignSystem.Typography.body(16))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: DesignSystem.Space.x1)
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                Text(quadrant.subtitle)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1 + 1) {
                if items.isEmpty {
                    Text("Пусто")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } else {
                    ForEach(preview.visible, id: \.uuid) { task in
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if preview.showsOverflow {
                        Text("...")
                            .font(DesignSystem.Typography.bodyBold(15))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .accessibilityLabel("Есть ещё задачи")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Space.x3)
        .frame(maxWidth: .infinity, minHeight: EisenhowerMatrixLayout.cardHeight, maxHeight: EisenhowerMatrixLayout.cardHeight, alignment: .topLeading)
        .background(shape.fill(DesignSystem.Colors.surface))
        .overlay(
            shape.strokeBorder(
                showsBorder ? DesignSystem.Colors.divider : .clear,
                lineWidth: DesignSystem.Stroke.regular
            )
        )
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Открыть список задач квадранта")
    }
}

#Preview {
    EisenhowerMatrixView()
        .modelContainer(for: [TaskItem.self], inMemory: true)
}
