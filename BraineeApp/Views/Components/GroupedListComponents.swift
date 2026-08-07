//
//  GroupedListComponents.swift
//  BraineeApp
//
//  Переиспользуемые блоки inset-grouped UI (карточки, строки, поиск).

import SwiftUI

/// Заголовок секции над карточкой.
struct GroupedSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.sectionHeader(12))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Space.x1)
            .padding(.bottom, DesignSystem.Space.x1)
            .textCase(nil)
    }
}

/// Карточка-группа: скругление 16, фон surface, без рамки и тени.
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .groupedCardBackground()
    }
}

/// Секция: заголовок + карточка + вертикальный воздух.
struct GroupedSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title, !title.isEmpty {
                GroupedSectionHeader(title: title)
            }
            GroupedCard(content: content)
        }
    }
}

/// Строка настроек: иконка (accent) → текст → chevron.
struct GroupedNavRow: View {
    let title: String
    let systemImage: String
    var showsChevron: Bool = true

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(accentColor)
                .frame(width: DesignSystem.Space.x5, height: DesignSystem.Space.x5)

            Text(title)
                .font(DesignSystem.Typography.body(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer(minLength: DesignSystem.Space.x2)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2 + 2)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: accentPaletteRaw)
    }
}

/// Капсульный поиск как в референсе.
struct GroupedSearchField: View {
    @Binding var text: String
    var placeholder: String = "Поиск..."

    @AppStorage(AccentPalette.storageKey) private var accentPaletteRaw = AccentPalette.orange.rawValue

    private var accentColor: Color {
        AccentPalette.resolved(from: accentPaletteRaw).color
    }

    var body: some View {
        HStack(spacing: DesignSystem.Space.x2) {
            Image(systemName: DesignSystem.Icon.search)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(accentColor)

            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, DesignSystem.Space.x3)
        .padding(.vertical, DesignSystem.Space.x2)
        .background(
            Capsule(style: .continuous)
                .fill(DesignSystem.Colors.chip)
        )
    }
}

/// Стек строк с inset-разделителями.
struct GroupedRowsStack<Data: RandomAccessCollection, Row: View>: View
where Data.Element: Identifiable {
    let data: Data
    var dividerLeading: CGFloat = DesignSystem.Space.rowIconInset
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                row(element)
                if index < data.count - 1 {
                    InsetDivider(leading: dividerLeading)
                }
            }
        }
    }
}

extension View {
    /// Горизонтальные отступы экрана для grouped-контента.
    func groupedScreenPadding() -> some View {
        padding(.horizontal, DesignSystem.Space.screenInset)
    }
}
