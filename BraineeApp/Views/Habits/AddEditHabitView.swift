//
//  AddEditHabitView.swift
//  BraineeApp
//
//  Форма создания и редактирования привычки.

import SwiftUI

struct AddEditHabitView: View {
    @Environment(\.dismiss) private var dismiss

    var habit: Habit?
    var onSave: (String) -> Void
    var onDelete: (() -> Void)?

    @State private var title = ""
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { habit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                        .font(DesignSystem.Typography.body())
                } header: {
                    Text("Привычка")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(DesignSystem.Colors.surface)

                if isEditing {
                    Section {
                        Button("Удалить привычку", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                    .listRowBackground(DesignSystem.Colors.surface)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle(isEditing ? "Редактировать" : "Новая привычка")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(TaskInputValidation.normalizedTitle(title))
                        dismiss()
                    }
                    .disabled(!TaskInputValidation.canSaveTitle(title))
                }
            }
            .alert("Удалить привычку?", isPresented: $showingDeleteConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("История отметок этой привычки будет удалена.")
            }
            .onAppear {
                title = habit?.title ?? ""
            }
        }
        .tint(DesignSystem.Colors.accent)
    }
}
