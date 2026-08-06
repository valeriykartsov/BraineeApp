//
//  EmptyTasksView.swift
//  BraineeApp
//

import SwiftUI

struct EmptyTasksView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Нет задач", systemImage: "checklist")
        } description: {
            Text("Нажмите «+», чтобы добавить первую задачу")
        }
    }
}
