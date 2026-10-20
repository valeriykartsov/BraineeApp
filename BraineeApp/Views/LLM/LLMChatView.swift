//
//  LLMChatView.swift
//  BraineeApp
//
//  Чат вкладки «LLM» (LLM-3). Режим «Задача»: фраза → черновик → обычная форма задачи →
//  сохранение через TaskService. Каждый запрос отправляется отдельно, без предыдущих сообщений (D-26).
//  История живёт только в памяти до закрытия приложения и нигде не сохраняется.

import SwiftUI
import SwiftData

struct LLMChatMessage: Identifiable {
    enum Kind {
        case user(String)
        case draft(TaskDraft)
        case error(String, retryText: String)
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
    @State private var isSending = false
    @State private var openedDraft: TaskDraft?
    @State private var savedDraftIDs: Set<UUID> = []
    @FocusState private var isInputFocused: Bool

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && !trimmedInput.isEmpty && trimmedInput.count <= TaskDraftService.maxInputLength
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
            Text("Опишите задачу словами")
                .font(DesignSystem.Typography.headline(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("Например: «Завтра в 10 позвонить в банк, важно». LLM подготовит черновик — вы проверите его в обычной форме и сохраните. Без сохранения ничего не меняется.")
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
        case .error(let text, let retryText):
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.danger)
                HStack(spacing: DesignSystem.Space.x4) {
                    Button("Повторить") { send(retryText) }
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
                Label("Задача", systemImage: "checklist")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Space.x2)
                    .padding(.vertical, DesignSystem.Space.x1)
                    .background(Capsule().fill(DesignSystem.Colors.accent))
                    .accessibilityLabel("Режим: задача")
                Spacer()
                if trimmedInput.count > TaskDraftService.maxInputLength {
                    Text("\(trimmedInput.count)/\(TaskDraftService.maxInputLength)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.danger)
                }
            }

            HStack(alignment: .bottom, spacing: DesignSystem.Space.x2) {
                TextField("Опишите задачу…", text: $input, axis: .vertical)
                    .font(DesignSystem.Typography.body(16))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, DesignSystem.Space.x3)
                    .padding(.vertical, DesignSystem.Space.x2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(DesignSystem.Colors.chip)
                    )
                Button {
                    send(trimmedInput)
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

    // MARK: - Действия

    private var draftContext: TaskDraftContext {
        TaskDraftContext.make(groups: groups, tags: tags)
    }

    private func send(_ text: String) {
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
                let provider = try OpenRouterProvider.fromSettings()
                let draft = try await TaskDraftGenerator(provider: provider).draft(from: text, context: context)
                messages.append(LLMChatMessage(kind: .draft(draft)))
            } catch let error as LLMError {
                messages.append(LLMChatMessage(kind: .error(error.userMessage, retryText: text)))
            } catch let error as TaskDraftError {
                messages.append(LLMChatMessage(kind: .error(error.userMessage, retryText: text)))
            } catch {
                messages.append(LLMChatMessage(kind: .error(LLMError.invalidResponse.userMessage, retryText: text)))
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
