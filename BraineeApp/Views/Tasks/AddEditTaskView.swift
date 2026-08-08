//
//  AddEditTaskView.swift
//  BraineeApp
//
//  Форма создания и редактирования задачи: название, статус, дедлайн, напоминания, приоритет, теги.

import SwiftUI
import SwiftData

struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// UUID редактируемой задачи (без удержания @Model — иначе SwiftData дёргает UI при вводе).
    private let editingTaskUUID: UUID?
    private let initialSnapshot: TaskFormSnapshot
    var onSave: (TaskFormData) -> Void
    var onDelete: ((TaskItem) -> Void)?

    @State private var title: String
    @State private var hasDeadline: Bool
    @State private var hasDeadlineTime: Bool
    @State private var deadline: Date
    @State private var reminderOffsets: [TaskReminderOffset]
    @State private var priority: TaskPriority
    @State private var status: TaskStatus
    @State private var taskDetails: String
    @State private var selectedTagUUIDs: Set<UUID>
    /// Зафиксированное название после ОК / открытия формы — цель сброса «Отмена».
    @State private var titleCommitted: String
    /// Зафиксированное описание после ОК / открытия формы — цель сброса «Отмена».
    @State private var detailsCommitted: String
    /// Последнее поле ввода: клавиатура часто снимает фокус до action кнопки тулбара.
    @State private var lastFocusedField: FormField?
    @State private var showingDeleteConfirm = false
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false
    @State private var showingDiscardConfirm = false
    @State private var showingFieldResetConfirm = false
    @State private var pendingFieldReset: TaskFormTextField?
    @FocusState private var focusedField: FormField?

    private enum FormField: Hashable {
        case title
        case details
    }

    private var isEditing: Bool { editingTaskUUID != nil }
    private var detailsLimit: Int { TaskInputValidation.detailsMaxLength }

    private var currentSnapshot: TaskFormSnapshot {
        TaskFormSnapshot(
            title: title,
            taskDetails: taskDetails,
            status: status,
            priority: priority,
            hasDeadline: hasDeadline,
            hasDeadlineTime: hasDeadlineTime,
            deadline: hasDeadline ? deadline : nil,
            reminderOffsets: reminderOffsets,
            selectedTagUUIDs: selectedTagUUIDs
        )
    }

    private var isDirty: Bool {
        currentSnapshot != initialSnapshot
    }

    private var dateDisplayText: String {
        guard hasDeadline else { return "Не указана" }
        return deadline.formatted(date: .long, time: .omitted)
    }

    private var timeDisplayText: String {
        guard hasDeadline, hasDeadlineTime else { return "Не указано" }
        return deadline.formatted(date: .omitted, time: .shortened)
    }

    init(
        task: TaskItem? = nil,
        onSave: @escaping (TaskFormData) -> Void,
        onDelete: ((TaskItem) -> Void)? = nil
    ) {
        self.editingTaskUUID = task?.uuid
        self.onSave = onSave
        self.onDelete = onDelete

        let snapshot = task.map(TaskFormSnapshot.init) ?? TaskFormSnapshot()
        self.initialSnapshot = snapshot

        _title = State(initialValue: snapshot.title)
        _titleCommitted = State(initialValue: snapshot.title)
        _taskDetails = State(initialValue: snapshot.taskDetails)
        _detailsCommitted = State(initialValue: snapshot.taskDetails)
        _status = State(initialValue: snapshot.status)
        _priority = State(initialValue: snapshot.priority)
        _hasDeadline = State(initialValue: snapshot.hasDeadline)
        _hasDeadlineTime = State(initialValue: snapshot.hasDeadlineTime)
        _reminderOffsets = State(initialValue: snapshot.reminderOffsets)
        _selectedTagUUIDs = State(initialValue: snapshot.selectedTagUUIDs)
        _deadline = State(initialValue: task?.deadline ?? Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Space.sectionGap) {
                    GroupedSection(title: "Задача") {
                        TextField("Название", text: $title)
                            .font(DesignSystem.Typography.body(16))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .focused($focusedField, equals: .title)
                            .padding(.horizontal, DesignSystem.Space.x3)
                            .padding(.vertical, DesignSystem.Space.x2 + 2)
                    }

                    GroupedSection(title: "Описание") {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                            TextField("Описание", text: $taskDetails, axis: .vertical)
                                .font(DesignSystem.Typography.body(16))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(3...6)
                                .focused($focusedField, equals: .details)
                                .onChange(of: taskDetails) { _, newValue in
                                    if newValue.count > detailsLimit {
                                        taskDetails = String(newValue.prefix(detailsLimit))
                                    }
                                }

                            HStack {
                                Spacer()
                                Text("\(taskDetails.count)/\(detailsLimit)")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(
                                        taskDetails.count >= detailsLimit
                                            ? DesignSystem.Colors.danger
                                            : DesignSystem.Colors.accent
                                    )
                            }
                        }
                        .padding(DesignSystem.Space.x3)
                    }

                    if isEditing {
                        GroupedSection(title: "Статус") {
                            Picker("Статус", selection: $status) {
                                ForEach(TaskStatus.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(DesignSystem.Space.x3)
                        }
                    }

                    GroupedSection(title: "Дедлайн") {
                        VStack(spacing: 0) {
                            selectionRow(
                                title: "Дата",
                                value: dateDisplayText,
                                isSet: hasDeadline
                            ) {
                                focusedField = nil
                                showingDatePicker = true
                            }

                            if hasDeadline {
                                InsetDivider(leading: DesignSystem.Space.x3)
                                selectionRow(
                                    title: "Время",
                                    value: timeDisplayText,
                                    isSet: hasDeadlineTime
                                ) {
                                    focusedField = nil
                                    showingTimePicker = true
                                }
                            }
                        }
                    }

                    if hasDeadline {
                        remindersSection
                    }

                    GroupedSection(title: "Приоритет") {
                        VStack(spacing: 0) {
                            ForEach(Array(TaskPriority.allCases.enumerated()), id: \.element.id) { index, level in
                                Button {
                                    priority = level
                                } label: {
                                    HStack(spacing: DesignSystem.Space.x3) {
                                        Circle()
                                            .fill(PriorityStyle.color(for: level))
                                            .frame(width: DesignSystem.Space.x2, height: DesignSystem.Space.x2)
                                        Text(level.title)
                                            .font(DesignSystem.Typography.body(16))
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        Spacer()
                                        if priority == level {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(DesignSystem.Colors.accent)
                                        }
                                    }
                                    .padding(.horizontal, DesignSystem.Space.x3)
                                    .padding(.vertical, DesignSystem.Space.x2 + 2)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < TaskPriority.allCases.count - 1 {
                                    InsetDivider(leading: DesignSystem.Space.x3)
                                }
                            }
                        }
                    }

                    TaskFormTagsSection(selectedTagUUIDs: $selectedTagUUIDs)

                    if isEditing {
                        GroupedSection {
                            Button("Удалить задачу", role: .destructive) {
                                showingDeleteConfirm = true
                            }
                            .font(DesignSystem.Typography.body(16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Space.x3)
                            .padding(.vertical, DesignSystem.Space.x2 + 2)
                        }
                    }
                }
                .groupedScreenPadding()
                .padding(.top, DesignSystem.Space.x2)
                .padding(.bottom, DesignSystem.Space.x4)
            }
            .appScreenBackground()
            .tint(DesignSystem.Colors.accent)
            .navigationTitle(isEditing ? "Редактировать" : "Новая задача")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .interactiveDismissDisabled(isDirty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { attemptDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!TaskInputValidation.canSaveTitle(title))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Отмена") {
                        requestFieldReset()
                    }
                    .disabled(!canResetCurrentField)
                    Spacer()
                    Button("ОК") {
                        acceptFocusedField()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Удалить задачу?", isPresented: $showingDeleteConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    deleteEditingTask()
                }
            } message: {
                Text("Задача будет перемещена в «Удалённые задачи» в профиле.")
            }
            .alert(fieldResetAlertTitle, isPresented: $showingFieldResetConfirm) {
                Button("Вернуться", role: .cancel) {
                    pendingFieldReset = nil
                }
                Button("Сбросить", role: .destructive) {
                    applyPendingFieldReset()
                }
            } message: {
                Text(fieldResetAlertMessage)
            }
            .alert("Несохранённые изменения", isPresented: $showingDiscardConfirm) {
                Button("Вернуться к редактированию", role: .cancel) {}
                Button("Закрыть без сохранения", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("В карточке есть несохранённые изменения. Закрыть и потерять их?")
            }
            .sheet(isPresented: $showingDatePicker) {
                DateTimePickerSheet(
                    title: "Дата",
                    selection: $deadline,
                    components: .date,
                    onConfirm: {
                        hasDeadline = true
                        showingDatePicker = false
                    },
                    onReset: {
                        hasDeadline = false
                        hasDeadlineTime = false
                        reminderOffsets = []
                        showingDatePicker = false
                    }
                )
            }
            .sheet(isPresented: $showingTimePicker) {
                DateTimePickerSheet(
                    title: "Время",
                    selection: $deadline,
                    components: .hourAndMinute,
                    onConfirm: {
                        hasDeadline = true
                        hasDeadlineTime = true
                        showingTimePicker = false
                    },
                    onReset: {
                        hasDeadlineTime = false
                        deadline = Calendar.current.startOfDay(for: deadline)
                        showingTimePicker = false
                    }
                )
            }
            .onChange(of: hasDeadline) { _, enabled in
                if !enabled {
                    hasDeadlineTime = false
                    reminderOffsets = []
                }
            }
            .onChange(of: focusedField) { _, field in
                if let field {
                    lastFocusedField = field
                }
            }
        }
    }

    // MARK: - Напоминания (как «Уведомление» в Calendar)

    private var remindersSection: some View {
        GroupedSection(title: "Напоминание") {
            VStack(spacing: 0) {
                if reminderOffsets.isEmpty {
                    reminderPickerRow(
                        title: "Уведомление",
                        valueTitle: "Нет",
                        selected: nil,
                        used: []
                    ) { choice in
                        if let choice {
                            reminderOffsets = [choice]
                        }
                    }
                } else {
                    ForEach(Array(reminderOffsets.indices), id: \.self) { index in
                        let item = reminderOffsets[index]
                        reminderPickerRow(
                            title: index == 0 ? "Уведомление" : "Уведомление \(index + 1)",
                            valueTitle: item.title,
                            selected: item,
                            used: Set(reminderOffsets)
                        ) { choice in
                            if let choice {
                                reminderOffsets[index] = choice
                                reminderOffsets = TaskReminderOffset.normalizedList(
                                    reminderOffsets.map(\.rawValue)
                                )
                            } else {
                                reminderOffsets.remove(at: index)
                            }
                        }
                        if index < reminderOffsets.count - 1
                            || reminderOffsets.count < TaskReminderOffset.maxCount {
                            InsetDivider(leading: DesignSystem.Space.x3)
                        }
                    }

                    if reminderOffsets.count < TaskReminderOffset.maxCount {
                        Button {
                            addReminder()
                        } label: {
                            Text("Добавить уведомление")
                                .font(DesignSystem.Typography.body(16))
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DesignSystem.Space.x3)
                                .padding(.vertical, DesignSystem.Space.x2 + 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func reminderPickerRow(
        title: String,
        valueTitle: String,
        selected: TaskReminderOffset?,
        used: Set<TaskReminderOffset>,
        onPick: @escaping (TaskReminderOffset?) -> Void
    ) -> some View {
        Menu {
            Button {
                onPick(nil)
            } label: {
                if selected == nil {
                    Label("Нет", systemImage: "checkmark")
                } else {
                    Text("Нет")
                }
            }

            Divider()

            ForEach(TaskReminderOffset.allCases) { offset in
                let isSelected = selected == offset
                let isTakenByOther = used.contains(offset) && !isSelected
                Button {
                    onPick(offset)
                } label: {
                    if isSelected {
                        Label(offset.title, systemImage: "checkmark")
                    } else {
                        Text(offset.title)
                    }
                }
                .disabled(isTakenByOther)
            }
        } label: {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text(valueTitle)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(
                        selected == nil
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.accent
                    )
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
            .contentShape(Rectangle())
        }
    }

    private func addReminder() {
        let used = Set(reminderOffsets)
        guard let next = TaskReminderOffset.allCases.first(where: { !used.contains($0) }) else { return }
        reminderOffsets.append(next)
        reminderOffsets = TaskReminderOffset.normalizedList(reminderOffsets.map(\.rawValue))
    }

    // MARK: - Клавиатура / отмена поля

    private var mappedFocused: TaskFormTextField? {
        switch focusedField {
        case .title: .title
        case .details: .details
        case .none: nil
        }
    }

    private var mappedLastFocused: TaskFormTextField? {
        switch lastFocusedField {
        case .title: .title
        case .details: .details
        case .none: nil
        }
    }

    private var canResetCurrentField: Bool {
        TaskFieldKeyboardReset.canReset(
            focused: mappedFocused,
            lastFocused: mappedLastFocused,
            title: title,
            titleCommitted: titleCommitted,
            details: taskDetails,
            detailsCommitted: detailsCommitted
        )
    }

    private func acceptFocusedField() {
        switch TaskFieldKeyboardReset.resetTarget(
            focused: mappedFocused,
            lastFocused: mappedLastFocused,
            title: title,
            titleCommitted: titleCommitted,
            details: taskDetails,
            detailsCommitted: detailsCommitted
        ) {
        case .title:
            titleCommitted = title
        case .details:
            detailsCommitted = taskDetails
        case .none:
            break
        }
        focusedField = nil
    }

    private var fieldResetAlertTitle: String {
        switch pendingFieldReset {
        case .title: "Сбросить название?"
        case .details, .none: "Сбросить описание?"
        }
    }

    private var fieldResetAlertMessage: String {
        switch pendingFieldReset {
        case .title: "Изменения в поле «Название» будут отменены."
        case .details, .none: "Изменения в поле «Описание» будут отменены."
        }
    }

    /// Сначала снимаем фокус (клавиатура), затем показываем подтверждение —
    /// иначе alert часто не появляется поверх закрывающейся клавиатуры.
    private func requestFieldReset() {
        let target = TaskFieldKeyboardReset.resetTarget(
            focused: mappedFocused,
            lastFocused: mappedLastFocused,
            title: title,
            titleCommitted: titleCommitted,
            details: taskDetails,
            detailsCommitted: detailsCommitted
        )
        guard let target else { return }
        pendingFieldReset = target
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingFieldResetConfirm = true
        }
    }

    private func applyPendingFieldReset() {
        switch pendingFieldReset {
        case .title:
            title = titleCommitted
        case .details:
            taskDetails = detailsCommitted
        case .none:
            break
        }
        pendingFieldReset = nil
    }

    private func attemptDismiss() {
        if isDirty {
            showingDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func deleteEditingTask() {
        guard let editingTaskUUID,
              let task = TaskItem.fetch(byUUID: editingTaskUUID, in: modelContext) else { return }
        onDelete?(task)
        dismiss()
    }

    private func selectionRow(
        title: String,
        value: String,
        isSet: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text(value)
                    .font(DesignSystem.Typography.body(16))
                    .foregroundStyle(
                        isSet
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textSecondary
                    )
            }
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x2 + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resolvedTags() -> [TaskTag] {
        let descriptor = FetchDescriptor<TaskTag>(
            sortBy: [SortDescriptor(\TaskTag.name)]
        )
        let allTags = (try? modelContext.fetch(descriptor)) ?? []
        return allTags.filter { selectedTagUUIDs.contains($0.uuid) }
    }

    private func save() {
        guard TaskInputValidation.canSaveTitle(title) else { return }

        let resolvedDeadline: Date?
        if hasDeadline {
            if hasDeadlineTime {
                resolvedDeadline = deadline
            } else {
                resolvedDeadline = Calendar.current.startOfDay(for: deadline)
            }
        } else {
            resolvedDeadline = nil
        }

        let formData = TaskFormData(
            title: TaskInputValidation.normalizedTitle(title),
            deadline: resolvedDeadline,
            hasDeadlineTime: hasDeadline && hasDeadlineTime,
            reminderOffsets: hasDeadline
                ? TaskReminderOffset.normalizedList(reminderOffsets.map(\.rawValue))
                : [],
            priority: priority,
            status: isEditing ? status : .new,
            taskDetails: TaskInputValidation.clampedDetails(taskDetails),
            selectedTags: resolvedTags()
        )
        onSave(formData)
        dismiss()
    }
}

// MARK: - Теги

private struct TaskFormTagsSection: View {
    @Binding var selectedTagUUIDs: Set<UUID>
    @Query(sort: \TaskTag.name) private var allTags: [TaskTag]

    var body: some View {
        GroupedSection(title: "Теги") {
            if allTags.isEmpty {
                Text("В библиотеке пока нет тегов. Добавьте их в Профиле.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(DesignSystem.Space.x3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allTags.enumerated()), id: \.element.uuid) { index, tag in
                        let isSelected = selectedTagUUIDs.contains(tag.uuid)
                        Button {
                            if isSelected {
                                selectedTagUUIDs.remove(tag.uuid)
                            } else {
                                selectedTagUUIDs.insert(tag.uuid)
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Space.x3) {
                                Image(systemName: DesignSystem.Icon.tag)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                Text(tag.name)
                                    .font(DesignSystem.Typography.body(16))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Space.x3)
                            .padding(.vertical, DesignSystem.Space.x2 + 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < allTags.count - 1 {
                            InsetDivider(leading: DesignSystem.Space.rowIconInset)
                        }
                    }
                }
            }
        }
    }
}

/// Лист выбора даты/времени с кнопками «ОК» и «Сброс».
private struct DateTimePickerSheet: View {
    let title: String
    @Binding var selection: Date
    let components: DatePickerComponents
    var onConfirm: () -> Void
    var onReset: () -> Void

    @State private var draft: Date

    init(
        title: String,
        selection: Binding<Date>,
        components: DatePickerComponents,
        onConfirm: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.title = title
        self._selection = selection
        self.components = components
        self.onConfirm = onConfirm
        self.onReset = onReset
        _draft = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Space.x4) {
                Group {
                    if components == .date {
                        DatePicker(title, selection: $draft, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    } else {
                        DatePicker(title, selection: $draft, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                    }
                }
                .labelsHidden()
                .tint(DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Space.x3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
            .navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Сброс") {
                        onReset()
                    }
                    .foregroundStyle(DesignSystem.Colors.danger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ОК") {
                        selection = draft
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(DesignSystem.Colors.accent)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    AddEditTaskView(onSave: { _ in })
        .modelContainer(for: [TaskItem.self, TaskTag.self], inMemory: true)
}
