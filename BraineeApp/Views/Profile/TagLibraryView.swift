//
//  TagLibraryView.swift
//  BraineeApp
//
//  Библиотека тегов в grouped-карточке.

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
        GroupedSection(title: "Библиотека тегов") {
            VStack(spacing: 0) {
                if tags.isEmpty {
                    Text("Нет тегов")
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Space.x4)
                } else {
                    ForEach(Array(tags.enumerated()), id: \.element.uuid) { index, tag in
                        tagRow(tag)
                        if index < tags.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.rowIconInset)
                        }
                    }
                }

                if !tags.isEmpty {
                    InsetDivider(leading: DesignSystem.Space.rowIconInset)
                }

                Button {
                    showingAddTag = true
                } label: {
                    GroupedNavRow(
                        title: "Добавить тег",
                        systemImage: "plus",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
            }
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

    private func tagRow(_ tag: TaskTag) -> some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Image(systemName: DesignSystem.Icon.tag)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)

            Text(tag.name)
                .font(DesignSystem.Typography.body(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer(minLength: DesignSystem.Space.x2)

            Text("\(tag.tasks?.count ?? 0)")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            HStack(spacing: 0) {
                IconTapButton(
                    systemName: DesignSystem.Icon.pencil,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Редактировать тег"
                ) {
                    beginEdit(tag)
                }

                IconTapButton(
                    systemName: DesignSystem.Icon.trash,
                    tint: DesignSystem.Colors.accent,
                    compact: true,
                    accessibilityLabel: "Удалить тег"
                ) {
                    askDelete(tag)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2 + 2)
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
    ScrollView {
        TagLibraryView()
            .groupedScreenPadding()
    }
    .appScreenBackground()
    .modelContainer(for: TaskTag.self, inMemory: true)
}
