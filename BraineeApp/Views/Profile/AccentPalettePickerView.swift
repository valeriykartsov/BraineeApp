//
//  AccentPalettePickerView.swift
//  BraineeApp
//
//  Выбор акцентного цвета: список с подтверждением или отменой.

import SwiftUI

struct AccentPalettePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let current: AccentPalette
    var onConfirm: (AccentPalette) -> Void

    @State private var draft: AccentPalette

    init(current: AccentPalette, onConfirm: @escaping (AccentPalette) -> Void) {
        self.current = current
        self.onConfirm = onConfirm
        _draft = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(AccentPalette.allCases) { palette in
                    Button {
                        draft = palette
                    } label: {
                        HStack(spacing: DesignSystem.Space.x3) {
                            Circle()
                                .fill(palette.color)
                                .frame(width: DesignSystem.Space.x6, height: DesignSystem.Space.x6)

                            Text(palette.title)
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            Spacer()

                            if draft == palette {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(draft.color)
                            }
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
            .navigationTitle("Акцентный цвет")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onConfirm(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(draft.color)
        }
    }
}

#Preview {
    AccentPalettePickerView(current: .orange, onConfirm: { _ in })
}
