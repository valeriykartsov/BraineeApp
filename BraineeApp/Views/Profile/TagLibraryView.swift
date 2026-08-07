//
//  TagLibraryView.swift
//  BraineeApp
//
//  Библиотека тегов в профиле: добавление, редактирование и удаление тегов.

import SwiftUI
import SwiftData

struct TagLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskTag.name) private var tags: [TaskTag]

    @State private var newTagName = ""
    @State private var showingAddTag = false

    @State private var editingTag: TaskTag?
    @State private var editedTagName = ""
    @State private var showingEditTag = false

    @State private var tagPendingDeletion: TaskTag?
    @State private var showingDeleteConfirm = false

    var body: some View {
        Section {
            if tags.isEmpty {
                Text("Нет тегов")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    HStack(spacing: 4) {
                        TagChipView(name: tag.name)
                        Spacer(minLength: 8)
                        Text("\(tag.tasks?.count ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 20, alignment: .trailing)

                        IconTapButton(
                            systemName: "pencil",
                            tint: .accentColor,
                            accessibilityLabel: "Редактировать тег"
                        ) {
                            beginEdit(tag)
                        }

                        IconTapButton(
                            systemName: "trash",
                            role: .destructive,
                            accessibilityLabel: "Удалить тег"
                        ) {
                            askDelete(tag)
                        }
                    }
                }
                .onDelete(perform: requestDeleteFromSwipe)
            }

            Button {
                showingAddTag = true
            } label: {
                Label("Добавить тег", systemImage: "plus.circle")
            }
        } header: {
            Text("Библиотека тегов")
        } footer: {
            Text("Теги можно назначать задачам при создании и редактировании.")
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
        .alert("Редактировать тег", isPresented: $showingEditTag) {
            TextField("Название", text: $editedTagName)
            Button("Отмена", role: .cancel) {
                editingTag = nil
                editedTagName = ""
            }
            Button("Сохранить") {
                saveEditedTag()
            }
        }
        .alert("Удалить тег?", isPresented: $showingDeleteConfirm) {
            Button("Отмена", role: .cancel) {
                tagPendingDeletion = nil
            }
            Button("Удалить", role: .destructive) {
                if let tag = tagPendingDeletion {
                    deleteTag(tag)
                }
                tagPendingDeletion = nil
            }
        } message: {
            if let name = tagPendingDeletion?.name {
                Text("Тег «\(name)» будет удалён из библиотеки и с задач.")
            } else {
                Text("Тег будет удалён из библиотеки и с задач.")
            }
        }
    }

    private func beginEdit(_ tag: TaskTag) {
        editingTag = tag
        editedTagName = tag.name
        showingEditTag = true
    }

    private func askDelete(_ tag: TaskTag) {
        tagPendingDeletion = tag
        showingDeleteConfirm = true
    }

    /// Свайп тоже спрашивает подтверждение, а не удаляет сразу.
    private func requestDeleteFromSwipe(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        askDelete(tags[index])
    }

    private func createTag() {
        let existingNames = tags.map(\.name)
        guard TaskInputValidation.canCreateTag(name: newTagName, existingNames: existingNames) else {
            newTagName = ""
            return
        }
        modelContext.insert(TaskTag(name: TaskInputValidation.normalizedTagName(newTagName)))
        newTagName = ""
        modelContext.persistToJSON()
    }

    private func saveEditedTag() {
        guard let tag = editingTag else { return }
        let existingNames = tags.map(\.name)
        guard TaskInputValidation.canRenameTag(
            name: editedTagName,
            existingNames: existingNames,
            currentName: tag.name
        ) else {
            editingTag = nil
            editedTagName = ""
            return
        }
        tag.name = TaskInputValidation.normalizedTagName(editedTagName)
        editingTag = nil
        editedTagName = ""
        modelContext.persistToJSON()
    }

    private func deleteTag(_ tag: TaskTag) {
        modelContext.delete(tag)
        modelContext.persistToJSON()
    }
}

#Preview {
    Form {
        TagLibraryView()
    }
    .modelContainer(for: TaskTag.self, inMemory: true)
}
