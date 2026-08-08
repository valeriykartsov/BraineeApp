//
//  SwipeToDeleteRow.swift
//  BraineeApp
//
//  Свайп справа налево: короткий — иконка удаления, полный — удаление сразу.

import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    /// Эта строка сейчас «открыта» (видна кнопка удаления).
    var isOpen: Bool
    var onOpen: () -> Void
    var onClose: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false

    private let revealWidth: CGFloat = 72
    private let fullSwipeThreshold: CGFloat = 140

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground
                .opacity(offset < -4 ? 1 : 0)

            content()
                .offset(x: offset)
                .highPriorityGesture(swipeGesture)
        }
        .clipped()
        .onChange(of: isOpen) { _, open in
            guard !open, !isDragging else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                offset = 0
            }
        }
    }

    private var deleteBackground: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button {
                    HapticFeedback.success()
                    withAnimation(.easeOut(duration: 0.15)) {
                        offset = 0
                    }
                    onDelete()
                    onClose()
                } label: {
                    Image(systemName: DesignSystem.Icon.trash)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: revealWidth, height: geo.size.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Удалить")
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(DesignSystem.Colors.danger)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }

                if !isDragging {
                    isDragging = true
                    dragStartOffset = offset
                }
                let next = min(0, dragStartOffset + horizontal)
                offset = next
                if next < -12 {
                    onOpen()
                }
            }
            .onEnded { value in
                defer {
                    isDragging = false
                    dragStartOffset = 0
                }

                let horizontal = value.translation.width
                let predicted = offset + value.predictedEndTranslation.width * 0.12

                if predicted <= -fullSwipeThreshold || horizontal <= -fullSwipeThreshold {
                    HapticFeedback.success()
                    withAnimation(.easeOut(duration: 0.12)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        onDelete()
                        onClose()
                        offset = 0
                    }
                    return
                }

                if predicted <= -revealWidth * 0.45 {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        offset = -revealWidth
                    }
                    onOpen()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        offset = 0
                    }
                    onClose()
                }
            }
    }
}
