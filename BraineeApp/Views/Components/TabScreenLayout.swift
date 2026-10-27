//
//  TabScreenLayout.swift
//  BraineeApp
//
//  Прокрутка под шапкой и капсулой панели вкладок, как в Телеграме (п. 61):
//  содержимое заезжает под них, но при старте стоит под шапкой, а в конце списка — над капсулой.
//  Отступы ставятся внутри экрана: снаружи `NavigationStack` вкладки они до прокрутки не доходят.

import SwiftUI

private struct TabBarReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct TabBarInsetAppliedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Сколько места снизу занимает капсула панели вкладок (при клавиатуре — до её верха). Задаёт корень.
    var tabBarReserve: CGFloat {
        get { self[TabBarReserveKey.self] }
        set { self[TabBarReserveKey.self] = newValue }
    }

    /// Отступ под капсулу уже поставлен внешним экраном — вложенные его не повторяют.
    var tabBarInsetApplied: Bool {
        get { self[TabBarInsetAppliedKey.self] }
        set { self[TabBarInsetAppliedKey.self] = newValue }
    }
}

/// Отступ под капсулу снизу: прокрутка тянется под капсулу, а конец списка встаёт над ней.
/// Ставится только самым внешним экраном с фоном (`appScreenBackground`).
struct TabBarBottomInset: ViewModifier {
    var enabled: Bool
    @Environment(\.tabBarReserve) private var reserve
    @Environment(\.tabBarInsetApplied) private var applied

    func body(content: Content) -> some View {
        if enabled, !applied, reserve > 0 {
            content
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: reserve)
                        .allowsHitTesting(false)
                }
                .environment(\.tabBarInsetApplied, true)
        } else {
            content
        }
    }
}

/// Экран вкладки: шапка закреплена поверх прокрутки. Содержимое при старте под шапкой,
/// при прокрутке уходит под неё — на iOS 26 с системным размытием края, на iOS 18 — под материалом.
/// Кнопки шапки лежат поверх содержимого и нажимаются.
struct TabScreenLayout<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        let body = VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        if #available(iOS 26.0, *) {
            body.safeAreaBar(edge: .top, spacing: 0) {
                VStack(spacing: 0) { header() }
            }
        } else {
            body.safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) { header() }
                    .background(.ultraThinMaterial)
            }
        }
    }
}
