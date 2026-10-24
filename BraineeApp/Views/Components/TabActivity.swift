//
//  TabActivity.swift
//  BraineeApp
//
//  Активна ли вкладка, на которой показан экран. Вкладки не уничтожаются при переключении,
//  поэтому лист или запрос скрытой вкладки остался бы поверх другой (переход из уведомления или виджета).

import SwiftUI

private struct TabActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isTabActive: Bool {
        get { self[TabActiveKey.self] }
        set { self[TabActiveKey.self] = newValue }
    }
}

private struct DismissOnTabLeave: ViewModifier {
    @Environment(\.isTabActive) private var isTabActive
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isTabActive) { _, active in
            if !active { isPresented = false }
        }
    }
}

extension View {
    /// Закрывает лист или запрос, когда вкладку покидают; открытый экран вкладки при этом не меняется.
    func dismissOnTabLeave(_ isPresented: Binding<Bool>) -> some View {
        modifier(DismissOnTabLeave(isPresented: isPresented))
    }
}
