//
//  TagLibraryView.swift
//  BraineeApp
//
//  Библиотека тегов в профиле: добавление и удаление тегов для задач.

import SwiftUI
import SwiftData

struct TagLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskTag.name) private var tags: [TaskTag]

    @State private var newTagName = ""
    @State private var showingAddTag = false

    var body: some View {
        Section {
            if tags.isEmpty {
                Text("Нет тегов")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    HStack {
                        TagChipView(name: tag.name)
                        Spacer()
                        Text("\(tag.tasks?.count ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteTags)
            }

            Button {
                showingAddTag = true
            } label: {
                Label("Добавить тег", systemImage: "plus.circle")
            }
        } header: {
            Text("Библиотека тегов")
        } footer: {
            Text("Теги можно назначать задачам при создании и редактировании")
        }
        .alert("Новый тег", isPresented: $showingAddTag) {
            TextField("Название", text: $newTagName)
            Button("Отмена", role: .cancel) {
                newTagName = ""
            }
            Button("Создать") {
                createTag()
            }
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newTagName = ""
            return
        }
        modelContext.insert(TaskTag(name: trimmed))
        newTagName = ""
        modelContext.persistToJSON()
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
        modelContext.persistToJSON()
    }
}

#Preview {
    Form {
        TagLibraryView()
    }
    .modelContainer(for: TaskTag.self, inMemory: true)
}
