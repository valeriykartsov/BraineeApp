//
//  EmptyTasksView.swift
//  BraineeApp
//
//  Заглушка, когда в разделе ещё нет ни одной задачи.

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
