//
//  DeletedTasksFolderView.swift
//  BraineeApp
//
//  Удалённые задачи: строгий список в палитре дизайн-системы.

import SwiftUI
import SwiftData

struct DeletedTasksFolderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var deletedTasks: [TaskItem] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isSelecting = false
    @State private var showingClearAllConfirm = false

    var body: some View {
        Group {
            if deletedTasks.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                    Text("Папка пуста")
                        .font(DesignSystem.Typography.title(22))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Удалённые задачи появятся здесь")
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    PankinDivider()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DesignSystem.Space.x4)
            } else {
                List {
                    ForEach(deletedTasks, id: \.uuid) { task in
                        if isSelecting {
                            deletedRow(task)
                                .contentShape(Rectangle())
                                .onTapGesture { toggleSelection(task) }
                                .listRowBackground(DesignSystem.Colors.surface)
                        } else {
                            NavigationLink {
                                DeletedTaskDetailView(task: task) {
                                    restore(task)
                                }
                            } label: {
                                deletedRow(task)
                            }
                            .listRowBackground(DesignSystem.Colors.surface)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    restore(task)
                                } label: {
                                    Label("Восстановить", systemImage: "arrow.uturn.backward")
                                }
                                .tint(DesignSystem.Colors.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    permanentlyDelete(task)
                                } label: {
                                    Label("Удалить", systemImage: DesignSystem.Icon.trash)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(DesignSystem.Colors.background)
        .tint(DesignSystem.Colors.accent)
        .navigationTitle("Удалённые")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            if !deletedTasks.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelecting ? "Готово" : "Выбрать") {
                        withAnimation {
                            isSelecting.toggle()
                            if !isSelecting { selectedIDs.removeAll() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Удалить выбранные", role: .destructive) {
                            permanentlyDeleteSelected()
                        }
                        .disabled(selectedIDs.isEmpty)
                        Button("Очистить всё", role: .destructive) {
                            showingClearAllConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .alert("Очистить все удалённые задачи?", isPresented: $showingClearAllConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Очистить", role: .destructive) {
                permanentlyDeleteAll()
            }
        } message: {
            Text("Задачи будут удалены без возможности восстановления.")
        }
        .onAppear(perform: reloadDeletedTasks)
    }

    private func deletedRow(_ task: TaskItem) -> some View {
        HStack(spacing: DesignSystem.Space.x3) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(task.uuid) ? DesignSystem.Icon.checkboxOn : DesignSystem.Icon.checkboxOff)
                    .foregroundStyle(
                        selectedIDs.contains(task.uuid)
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
            }

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                Text(task.title)
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(task.category.title)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            if let deletedAt = task.deletedAt {
                Text(deletedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.data(11))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }

    private func reloadDeletedTasks() {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isSoftDeleted }
        )

        guard let fetched = try? modelContext.fetch(descriptor) else {
            deletedTasks = []
            return
        }

        deletedTasks = fetched.sorted {
            ($0.deletedAt ?? $0.createdAt) > ($1.deletedAt ?? $1.createdAt)
        }
    }

    private func toggleSelection(_ task: TaskItem) {
        if selectedIDs.contains(task.uuid) {
            selectedIDs.remove(task.uuid)
        } else {
            selectedIDs.insert(task.uuid)
        }
    }

    private func restore(_ task: TaskItem) {
        withAnimation {
            let uuid = task.uuid
            task.isSoftDeleted = false
            task.deletedAt = nil
            try? modelContext.save()
            modelContext.persistToJSON()
            deletedTasks.removeAll { $0.uuid == uuid }
            selectedIDs.remove(uuid)
            reloadDeletedTasks()
        }
    }

    private func permanentlyDelete(_ task: TaskItem) {
        withAnimation {
            modelContext.delete(task)
            try? modelContext.save()
            modelContext.persistToJSON()
            reloadDeletedTasks()
        }
    }

    private func permanentlyDeleteSelected() {
        let toDelete = deletedTasks.filter { selectedIDs.contains($0.uuid) }
        withAnimation {
            for task in toDelete { modelContext.delete(task) }
            selectedIDs.removeAll()
            isSelecting = false
            try? modelContext.save()
            modelContext.persistToJSON()
            reloadDeletedTasks()
        }
    }

    private func permanentlyDeleteAll() {
        withAnimation {
            for task in deletedTasks { modelContext.delete(task) }
            selectedIDs.removeAll()
            isSelecting = false
            try? modelContext.save()
            modelContext.persistToJSON()
            reloadDeletedTasks()
        }
    }
}

#Preview {
    NavigationStack {
        DeletedTasksFolderView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
