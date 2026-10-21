//
//  TagDistribution.swift
//  BraineeApp
//
//  Доли тегов для круговой диаграммы дашборда.
//  Считаются отметки тегов: задача с двумя тегами даёт по отметке каждому,
//  задача без тегов — сектор «Без тега». Сумма процентов — ровно 100.

import Foundation

struct TagShare: Equatable, Identifiable {
    let name: String
    let count: Int
    let percent: Int
    let isUntagged: Bool

    /// Отдельный id для «Без тега»: тег с таким же именем не должен с ним совпасть.
    var id: String { isUntagged ? "\u{0}untagged" : name }
}

enum TagDistribution {
    static let untaggedName = "Без тега"

    /// Доли по уже выбранным задачам (активные или все — решает вызывающий).
    /// Порядок: по убыванию числа задач, при равенстве — по имени; «Без тега» — последним.
    static func compute(from tasks: [TaskItem]) -> [TagShare] {
        var counts: [String: Int] = [:]
        var untagged = 0
        for task in tasks {
            if task.tags.isEmpty {
                untagged += 1
            } else {
                for tag in task.tags {
                    counts[tag.name, default: 0] += 1
                }
            }
        }

        var entries = counts
            .map { (name: $0.key, count: $0.value, isUntagged: false) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        if untagged > 0 {
            entries.append((name: untaggedName, count: untagged, isUntagged: true))
        }

        let percents = roundedPercents(entries.map(\.count))
        return zip(entries, percents).map { entry, percent in
            TagShare(name: entry.name, count: entry.count, percent: percent, isUntagged: entry.isUntagged)
        }
    }

    /// Целые проценты с суммой ровно 100 (метод наибольших остатков):
    /// сначала округление вниз, недостающие единицы — долям с наибольшей дробной частью.
    static func roundedPercents(_ counts: [Int]) -> [Int] {
        let total = counts.reduce(0, +)
        guard total > 0 else { return counts.map { _ in 0 } }

        let exact = counts.map { Double($0) * 100 / Double(total) }
        var result = exact.map { Int($0.rounded(.down)) }
        let missing = 100 - result.reduce(0, +)
        let byRemainder = exact.indices.sorted { lhs, rhs in
            let left = exact[lhs] - Double(result[lhs])
            let right = exact[rhs] - Double(result[rhs])
            if left != right { return left > right }
            return lhs < rhs
        }
        for index in byRemainder.prefix(missing) {
            result[index] += 1
        }
        return result
    }
}
