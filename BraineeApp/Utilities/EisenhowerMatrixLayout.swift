//
//  EisenhowerMatrixLayout.swift
//  BraineeApp
//
//  Превью задач в ячейке матрицы: лимит строк и признак «...».

import Foundation

enum EisenhowerMatrixLayout {
    /// Сколько названий задач показываем в карточке квадранта.
    static let previewTaskLimit = 3

    /// Высота всех четырёх контейнеров одинаковая.
    static let cardHeight: CGFloat = 168

    static func preview<T>(items: [T]) -> (visible: [T], showsOverflow: Bool) {
        if items.count > previewTaskLimit {
            return (Array(items.prefix(previewTaskLimit)), true)
        }
        return (items, false)
    }
}
