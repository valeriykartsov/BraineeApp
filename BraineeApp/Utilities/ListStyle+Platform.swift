//
//  ListStyle+Platform.swift
//  BraineeApp
//

import SwiftUI

extension View {
    @ViewBuilder
    func taskListStyle() -> some View {
#if os(iOS)
        self.listStyle(.insetGrouped)
#else
        self.listStyle(.automatic)
#endif
    }
}
