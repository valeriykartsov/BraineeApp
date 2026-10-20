//
//  LLMChatView.swift
//  BraineeApp
//
//  Чат вкладки «LLM». Режимы: «Задача» (LLM-3) — фраза → черновик; «Разбор» (LLM-6) — длинный
//  текст → до 10 черновиков. Каждый черновик → обычная форма задачи → сохранение через TaskService. Каждый запрос отправляется отдельно, без предыдущих сообщений (D-26).
//  История живёт только в памяти до закрытия приложения и нигде не сохраняется.

import SwiftUI
import SwiftData

/// Режим чата: что сделать с текстом. Выбирает пользователь (D-29…D-34).
enum LLMChatMode: CaseIterable, Identifiable {
    case task
    case inbox

    var id: Self { self }

    var title: String {
        switch self {
        case .task: "Задача"
        case .inbox: "Разбор"
        }
    }

    var systemImage: String {
        switch self {
        case .task: "checklist"
        case .inbox: "tray.full"
        }
    }

    var placeholder: String {
        switch self {
        case .task: "Опишите задачу…"
        case .inbox: "Вставьте список дел или мысли…"
        }
    }

    var maxInputLength: Int {
        switch self {
        case .task: TaskDraftService.maxInputLength
        case .inbox: InboxDraftService.maxInputLength
        }
    }
}

struct LLMChatMessage: Identifiable {
    enum Kind {
        case user(String)
        case draft(TaskDraft)
        /// Несколько черновиков из «Разбора» и пометки об отброшенном.
        case drafts([TaskDraft], notes: [String])
        case error(String, retryText: String, mode: LLMChatMode)
    }

    let id = UUID()
    let kind: Kind
}

struct LLMChatView: View {
    @Binding var messages: [LLMChatMessage]

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TaskGroup.sortOrder)])
    private var groups: [TaskGroup]

    @Query(sort: \TaskTag.name)
    private var tags: [TaskTag]

    @State private var input = ""
    @State private var mode: LLMChatMode = .task
    @State private var isSending = false
    @State private var openedDraft: TaskDraft?
    @State private var savedDraftIDs: Set<UUID> = []
    @FocusState private var isInputFocused: Bool

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && !trimmedInput.isEmpty && trimmedInput.count <= mode.maxInputLength
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Space.x3) {
                        if messages.isEmpty {
                            hint
                        }
                        ForEach(messages) { message in
                            messageView(message)
                                .id(message.id)
                        }
                        if isSending {
                            HStack(spacing: DesignSystem.Space.x2) {
                                ProgressView()
                                Text("Готовлю черновик…")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            .id("sending")
                        }
                    }
                    .padding(.horizontal, DesignSystem.Space.screenInset)
                    .padding(.vertical, DesignSystem.Space.x3)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isSending) { _, sending in
                    if sending {
                        withAnimation { proxy.scrollTo("sending", anchor: .bottom) }
                    }
                }
            }

            AppDivider()
            inputBar
        }
        .sheet(item: $openedDraft) { draft in
            AddEditTaskView(prefill: snapshot(for: draft), deadline: draft.deadline) { formData in
                save(formData, from: draft)
            }
        }
    }

    // MARK: - Сообщения

    private var hint: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text(mode == .task ? "Опишите задачу словами" : "Вставьте всё, что в голове")
                .font(DesignSystem.Typography.headline(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(mode == .task
                 ? "Например: «Завтра в 10 позвонить в банк, важно». LLM подготовит черновик — вы проверите его в обычной форме и сохраните. Без сохранения ничего не меняется."
                 : "Список дел, заметку или поток мыслей — до \(InboxDraftService.maxInputLength) символов. LLM разберёт текст на отдельные задачи (до \(InboxDraftService.maxDrafts)); каждую вы проверяете и сохраняете отдельно.")
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text("В OpenRouter уходят только ваш текст, сегодняшняя дата, часовой пояс и названия папок и тегов. История чата не сохраняется.")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.top, DesignSystem.Space.x4)
    }

    @ViewBuilder
    private func messageView(_ message: LLMChatMessage) -> some View {
        switch message.kind {
        case .user(let text):
            HStack {
                Spacer(minLength: DesignSystem.Space.x10)
                Text(text)
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Space.x3)
                    .padding(.vertical, DesignSystem.Space.x2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(DesignSystem.Colors.accent)
                    )
            }
        case .draft(let draft):
            draftCard(draft)
        case .drafts(let drafts, let notes):
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                Text("Черновиков: \(drafts.count). Сохраните нужные по одному.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                ForEach(drafts) { draft in
                    draftCard(draft)
                }
            }
        case .error(let text, let retryText, let retryMode):
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.danger)
                HStack(spacing: DesignSystem.Space.x4) {
                    Button("Повторить") { send(retryText, mode: retryMode) }
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .disabled(isSending)
                    Text("Задачу всегда можно создать вручную на вкладке «Задачи».")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .font(DesignSystem.Typography.body(15))
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Space.x3)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.dangerSoft)
            )
        }
    }

    private func draftCard(_ draft: TaskDraft) -> some View {
        let isSaved = savedDraftIDs.contains(draft.id)
        return VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text("Черновик задачи")
                .font(DesignSystem.Typography.sectionHeader())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text(draft.title)
                .font(DesignSystem.Typography.headline(17))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                draftRow("Срок", deadlineText(draft))
                draftRow("Приоритет", draft.priority.title)
                if !draft.tagNames.isEmpty {
                    draftRow("Теги", draft.tagNames.joined(separator: ", "))
                }
                if let groupName = draft.groupName {
                    draftRow("Папка", groupName)
                }
                if !draft.details.isEmpty {
                    draftRow("Описание", draft.details)
                }
            }

            ForEach(draft.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            if isSaved {
                Label("Задача сохранена", systemImage: "checkmark.circle.fill")
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.success)
                    .padding(.top, DesignSystem.Space.x1)
            } else {
                Button {
                    openedDraft = draft
                } label: {
                    Text("Открыть и сохранить")
                        .font(DesignSystem.Typography.bodyBold(15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Space.x2)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                                .fill(DesignSystem.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, DesignSystem.Space.x1)
            }
        }
        .padding(DesignSystem.Space.x3)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
                .fill(DesignSystem.Colors.surface)
        )
    }

    private func draftRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Space.x2) {
            Text(title)
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }

    private func deadlineText(_ draft: TaskDraft) -> String {
        guard let deadline = draft.deadline else { return "Не указан" }
        return draft.hasDeadlineTime
            ? deadline.formatted(date: .long, time: .shortened)
            : deadline.formatted(date: .long, time: .omitted)
    }

    // MARK: - Ввод

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            HStack(spacing: DesignSystem.Space.x2) {
                ForEach(LLMChatMode.allCases) { item in
                    modeChip(item)
                }
                Spacer()
                if trimmedInput.count > mode.maxInputLength {
                    Text("\(trimmedInput.count)/\(mode.maxInputLength)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.danger)
                }
            }

            HStack(alignment: .bottom, spacing: DesignSystem.Space.x2) {
                TextField(mode.placeholder, text: $input, axis: .vertical)
                    .font(DesignSystem.Typography.body(16))
                    .lineLimit(1...(mode == .inbox ? 8 : 5))
                    .focused($isInputFocused)
                    .padding(.horizontal, DesignSystem.Space.x3)
                    .padding(.vertical, DesignSystem.Space.x2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(DesignSystem.Colors.chip)
                    )
                Button {
                    send(trimmedInput, mode: mode)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary.opacity(0.4))
                }
                .disabled(!canSend)
                .accessibilityLabel("Отправить")
            }
        }
        .padding(.horizontal, DesignSystem.Space.screenInset)
        .padding(.vertical, DesignSystem.Space.x2)
        .background(DesignSystem.Colors.surface)
    }

    private func modeChip(_ item: LLMChatMode) -> some View {
        let isSelected = item == mode
        return Button {
            mode = item
        } label: {
            Label(item.title, systemImage: item.systemImage)
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Space.x2)
                .padding(.vertical, DesignSystem.Space.x1)
                .background(Capsule().fill(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.chip))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityLabel("Режим: \(item.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Действия

    private var draftContext: TaskDraftContext {
        TaskDraftContext.make(groups: groups, tags: tags)
    }

    private func send(_ text: String, mode: LLMChatMode) {
        guard !isSending, !text.isEmpty else { return }
        if text == trimmedInput {
            input = ""
        }
        messages.append(LLMChatMessage(kind: .user(text)))
        isSending = true
        let context = draftContext
        Task {
            defer { isSending = false }
            do {
                let provider = try LLMProviderFactory.make()
                switch mode {
                case .task:
                    let draft = try await TaskDraftGenerator(provider: provider).draft(from: text, context: context)
                    messages.append(LLMChatMessage(kind: .draft(draft)))
                case .inbox:
                    let result = try await InboxDraftGenerator(provider: provider).drafts(from: text, context: context)
                    messages.append(LLMChatMessage(kind: .drafts(result.drafts, notes: result.notes)))
                }
            } catch {
                let message = (error as? LLMError)?.userMessage
                    ?? (error as? TaskDraftError)?.userMessage
                    ?? LLMError.invalidResponse.userMessage
                messages.append(LLMChatMessage(kind: .error(message, retryText: text, mode: mode)))
            }
        }
    }

    private func snapshot(for draft: TaskDraft) -> TaskFormSnapshot {
        let tagUUIDs = Set(tags.filter { draft.tagNames.contains($0.name) }.map(\.uuid))
        return TaskFormSnapshot(
            title: draft.title,
            taskDetails: draft.details,
            status: .new,
            priority: draft.priority,
            hasDeadline: draft.deadline != nil,
            hasDeadlineTime: draft.hasDeadlineTime,
            deadline: draft.deadline,
            reminderOffsets: [],
            selectedTagUUIDs: tagUUIDs
        )
    }

    /// Единственное место, где меняются данные: после «Сохранить» в форме, через TaskService.
    private func save(_ formData: TaskFormData, from draft: TaskDraft) {
        let service = TaskService(context: modelContext)
        let task = service.create(from: formData)
        if let groupName = draft.groupName,
           let group = groups.first(where: { $0.category == .tasks && $0.name == groupName }) {
            service.move(task, to: group)
        }
        savedDraftIDs.insert(draft.id)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}
