//
//  DeletedTasksFolderView.swift
//  BraineeApp
//
//  Папка удалённых задач: просмотр, восстановление и окончательное удаление.

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
                ContentUnavailableView {
                    Label("Папка пуста", systemImage: "trash")
                } description: {
                    Text("Удалённые задачи появятся здесь")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(deletedTasks, id: \.uuid) { task in
                        if isSelecting {
                            deletedRow(task)
                                .contentShape(Rectangle())
                                .onTapGesture { toggleSelection(task) }
                        } else {
                            NavigationLink {
                                DeletedTaskDetailView(task: task) {
                                    restore(task)
                                }
                            } label: {
                                deletedRow(task)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    restore(task)
                                } label: {
                                    Label("Восстановить", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    permanentlyDelete(task)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
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
                        Image(systemName: "ellipsis.circle")
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
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(task.uuid) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(task.uuid) ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                Text(task.category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let deletedAt = task.deletedAt {
                Text(deletedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Загружает удалённые задачи вручную, чтобы не зависеть от тяжёлого @Query при открытии экрана.
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
            task.isSoftDeleted = false
            task.deletedAt = nil
            try? modelContext.save()
            modelContext.persistToJSON()
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
