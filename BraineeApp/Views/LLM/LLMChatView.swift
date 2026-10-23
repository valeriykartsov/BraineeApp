//
//  LLMChatView.swift
//  BraineeApp
//
//  Чат вкладки «LLM». Режимы: «Задача» (LLM-3) — фраза → черновик; «Разбор» (LLM-6) — длинный
//  текст → до 10 черновиков; «Итоги» (LLM-5) — цифры за день/неделю считает код, модель их описывает;
//  «План дня» (LLM-4) — порядок задач на сегодня, только просмотр, с согласием на отправку названий.
//  Каждый черновик → обычная форма задачи → сохранение через TaskService. Каждый запрос отправляется отдельно, без предыдущих сообщений (D-26).
//  История живёт только в памяти до закрытия приложения и нигде не сохраняется.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Режим чата: что сделать с текстом. Выбирает пользователь (D-29…D-34).
enum LLMChatMode: CaseIterable, Identifiable {
    case task
    case inbox
    case reflection
    case dayPlan
    case matrix

    var id: Self { self }

    var title: String {
        switch self {
        case .task: "Задача"
        case .inbox: "Разбор"
        case .reflection: "Итоги"
        case .dayPlan: "План дня"
        case .matrix: "Матрица"
        }
    }

    var systemImage: String {
        switch self {
        case .task: "checklist"
        case .inbox: "tray.full"
        case .reflection: "chart.bar"
        case .dayPlan: "calendar.day.timeline.left"
        case .matrix: "square.grid.2x2"
        }
    }

    var placeholder: String {
        switch self {
        case .task: "Опишите задачу…"
        case .inbox: "Вставьте список дел или мысли…"
        case .reflection, .dayPlan, .matrix: ""
        }
    }

    var maxInputLength: Int {
        switch self {
        case .task: TaskDraftService.maxInputLength
        case .inbox: InboxDraftService.maxInputLength
        case .reflection, .dayPlan, .matrix: 0
        }
    }
}

struct LLMChatMessage: Identifiable {
    enum Kind {
        case user(String)
        case draft(TaskDraft)
        /// Несколько черновиков из «Разбора» и пометки об отброшенном.
        case drafts([TaskDraft], notes: [String])
        /// «Итоги»: текст модели и цифры, которые посчитал код.
        case reflection(String, stats: ReflectionStats)
        /// «План дня»: порядок задач от модели, сопоставленный с задачами приложения.
        case dayPlan(DayPlan)
        /// «Матрица»: советы по задачам без срока, сопоставленные с задачами приложения (D-42).
        case matrixReview(MatrixReview)
        /// Сообщение приложения без запроса к модели.
        case info(String)
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

    /// Для «Итогов»: из задач и привычек считаются только числа (ReflectionService).
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [Habit]

    @State private var input = ""
    @State private var mode: LLMChatMode = .task
    @State private var isSending = false
    @State private var openedDraft: TaskDraft?
    @State private var savedDraftIDs: Set<UUID> = []
    @State private var showingDayPlanConsent = false
    @State private var showingMatrixConsent = false
    /// Ответ, который только что скопировали: на кнопке на пару секунд «Скопировано».
    @State private var copiedMessageID: UUID?
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
        .alert("Отправить названия задач?", isPresented: $showingDayPlanConsent) {
            Button("Отправить") {
                DayPlanService.giveConsent()
                send(LLMChatMode.dayPlan.title, mode: .dayPlan)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Для плана дня в OpenRouter уйдут названия задач на сегодня и просроченных (до \(DayPlanService.maxTasks)): название, приоритет, время срока и признак просрочки. Описания, теги и папки не отправляются. Спросим один раз; отозвать можно в «Профиль → Настройки → LLM».")
        }
        .alert("Отправить названия задач без срока?", isPresented: $showingMatrixConsent) {
            Button("Отправить") {
                MatrixReviewService.giveConsent()
                send(LLMChatMode.matrix.title, mode: .matrix)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Для разбора матрицы в OpenRouter уйдут задачи без срока (до \(MatrixReviewService.maxTasks)): название, приоритет и квадрант матрицы. Описания, теги, папки и подзадачи не отправляются. Спросим один раз; отозвать можно в «Профиль → Настройки → LLM».")
        }
    }

    // MARK: - Сообщения

    private var hint: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text(hintTitle)
                .font(DesignSystem.Typography.headline(16))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(hintText)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text(privacyText)
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.top, DesignSystem.Space.x4)
    }

    private var privacyText: String {
        switch mode {
        case .task, .inbox:
            "В OpenRouter уходят только ваш текст, сегодняшняя дата, часовой пояс и названия папок и тегов. История чата не сохраняется."
        case .reflection:
            "В OpenRouter уходят только числа: сколько задач выполнено, создано и просрочено, процент отметок привычек. Названия задач и привычек не отправляются. История чата не сохраняется."
        case .dayPlan:
            "В OpenRouter уходят названия задач на сегодня и просроченных (до \(DayPlanService.maxTasks)), их приоритет, время срока и текущее время. Описания, теги и папки не отправляются. История чата не сохраняется."
        case .matrix:
            "В OpenRouter уходят названия задач без срока (до \(MatrixReviewService.maxTasks)), их приоритет и квадрант матрицы. Описания, теги, папки и подзадачи не отправляются. История чата не сохраняется."
        }
    }

    private var hintTitle: String {
        switch mode {
        case .task: "Опишите задачу словами"
        case .inbox: "Вставьте всё, что в голове"
        case .reflection: "Итоги дня или недели"
        case .dayPlan: "План на сегодня"
        case .matrix: "Задачи без срока"
        }
    }

    private var hintText: String {
        switch mode {
        case .task:
            "Например: «Завтра в 10 позвонить в банк, важно». LLM подготовит черновик — вы проверите его в обычной форме и сохраните. Без сохранения ничего не меняется."
        case .inbox:
            "Список дел, заметку или поток мыслей — до \(InboxDraftService.maxInputLength) символов. LLM разберёт текст на отдельные задачи (до \(InboxDraftService.maxDrafts)); каждую вы проверяете и сохраняете отдельно."
        case .dayPlan:
            "LLM предложит порядок задач на сегодня и просроченных, примерное время и короткие советы. План только для просмотра — сроки и порядок задач в приложении не меняются."
        case .reflection:
            "Приложение посчитает выполненные, созданные и просроченные задачи и отметки привычек, а LLM коротко опишет, как прошёл период. Данные не меняются."
        case .matrix:
            "LLM посмотрит на задачи без срока и для каждой посоветует: запланировать (на этой неделе, в этом месяце или позже), делегировать или убрать. Только для просмотра — сроки, приоритеты и корзина не меняются."
        }
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
        case .reflection(let text, let stats):
            copyableAnswer(message.id, text: LLMAnswerText.reflection(text: text, stats: stats)) {
                reflectionCard(text: text, stats: stats)
            }
        case .dayPlan(let plan):
            copyableAnswer(message.id, text: LLMAnswerText.dayPlan(plan)) {
                dayPlanCard(plan)
            }
        case .matrixReview(let review):
            copyableAnswer(message.id, text: LLMAnswerText.matrixReview(review)) {
                matrixReviewCard(review)
            }
        case .info(let text):
            Label(text, systemImage: "info.circle")
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Ответ ассистента с кнопками «Копировать» (п. 8) и «Поделиться» (п. 23a, D-38) под карточкой
    /// и теми же пунктами в контекстном меню. Делится тем же текстом, что копируется.
    private func copyableAnswer<Card: View>(
        _ id: UUID,
        text: String,
        @ViewBuilder card: () -> Card
    ) -> some View {
        let isCopied = copiedMessageID == id
        return VStack(alignment: .trailing, spacing: DesignSystem.Space.x1) {
            card()
                .contextMenu {
                    Button {
                        copy(text, messageID: id)
                    } label: {
                        Label("Копировать", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: text) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                }
            HStack(spacing: DesignSystem.Space.x2) {
                ShareLink(item: text) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Space.x1)
                        .padding(.vertical, DesignSystem.Space.x1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Поделиться ответом")

            Button {
                copy(text, messageID: id)
            } label: {
                Label(isCopied ? "Скопировано" : "Копировать", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Space.x1)
                    .padding(.vertical, DesignSystem.Space.x1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCopied ? "Ответ скопирован" : "Копировать ответ")
            }
        }
    }

    private func copy(_ text: String, messageID: UUID) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#endif
        HapticFeedback.success()
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedMessageID = messageID
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copiedMessageID == messageID {
                withAnimation(.easeInOut(duration: 0.15)) {
                    copiedMessageID = nil
                }
            }
        }
    }

    private func matrixReviewCard(_ review: MatrixReview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text("Задачи без срока")
                .font(DesignSystem.Typography.sectionHeader())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            if !review.summary.isEmpty {
                Text(review.summary)
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            ForEach(MatrixReviewAction.allCases, id: \.self) { action in
                let items = review.items(for: action)
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                        Text(action.title)
                            .font(DesignSystem.Typography.bodyBold(15))
                            .foregroundStyle(DesignSystem.Colors.accent)
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(DesignSystem.Typography.body(15))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                let detail = [item.horizon?.title, item.note.isEmpty ? nil : item.note]
                                    .compactMap { $0 }
                                    .joined(separator: ". ")
                                if !detail.isEmpty {
                                    Text(detail)
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Space.x1)
                }
            }
            ForEach(review.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Text("Только для просмотра: сроки, приоритеты и корзина не меняются.")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Space.x3)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
                .fill(DesignSystem.Colors.surface)
        )
    }

    private func dayPlanCard(_ plan: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text("План на сегодня")
                .font(DesignSystem.Typography.sectionHeader())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            if !plan.summary.isEmpty {
                Text(plan.summary)
                    .font(DesignSystem.Typography.body(15))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
                ForEach(Array(plan.items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Space.x2) {
                        Text(item.suggestedTime ?? "\(index + 1).")
                            .font(DesignSystem.Typography.data())
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 48, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(DesignSystem.Typography.body(15))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            if !item.note.isEmpty {
                                Text(item.note)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.top, DesignSystem.Space.x1)
            ForEach(plan.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Text("Только для просмотра: сроки и порядок задач не меняются.")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Space.x3)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.group, style: .continuous)
                .fill(DesignSystem.Colors.surface)
        )
    }

    private func reflectionCard(text: String, stats: ReflectionStats) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.x2) {
            Text(stats.period == .today ? "Итоги дня" : "Итоги недели")
                .font(DesignSystem.Typography.sectionHeader())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            VStack(alignment: .leading, spacing: DesignSystem.Space.x1) {
                draftRow("Выполнено", "\(stats.completed)")
                draftRow("Создано", "\(stats.created)")
                draftRow("Просрочено", "\(stats.overdue) из \(stats.active) открытых")
                if let rate = stats.habitRatePercent {
                    draftRow("Привычки", "\(stats.habitCheckins) из \(stats.habitPossible) (\(rate)%)")
                }
            }
            Text(text)
                .font(DesignSystem.Typography.body(15))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.top, DesignSystem.Space.x1)
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
                modeMenu
                Spacer(minLength: 0)
                if mode.maxInputLength > 0, trimmedInput.count > mode.maxInputLength {
                    Text("\(trimmedInput.count)/\(mode.maxInputLength)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.danger)
                }
            }

            if mode == .dayPlan || mode == .matrix {
                Button(action: mode == .dayPlan ? requestDayPlan : requestMatrixReview) {
                    Text(mode == .dayPlan ? "Составить план на сегодня" : "Разобрать задачи без срока")
                        .font(DesignSystem.Typography.bodyBold(15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Space.x2)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                                .fill(isSending ? DesignSystem.Colors.textSecondary.opacity(0.4) : DesignSystem.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            } else if mode == .reflection {
                HStack(spacing: DesignSystem.Space.x2) {
                    ForEach(ReflectionPeriod.allCases) { period in
                        Button {
                            send(period.rawValue, mode: .reflection)
                        } label: {
                            Text(period == .today ? "Итоги за сегодня" : "Итоги за неделю")
                                .font(DesignSystem.Typography.bodyBold(15))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Space.x2)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                                        .fill(isSending ? DesignSystem.Colors.textSecondary.opacity(0.4) : DesignSystem.Colors.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSending)
                    }
                }
            } else {
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
        }
        .padding(.horizontal, DesignSystem.Space.screenInset)
        .padding(.vertical, DesignSystem.Space.x2)
        .background(DesignSystem.Colors.surface)
    }

    /// Режим — раскрывающееся меню (п. 9): на кнопке иконка и название текущего режима
    /// в цвете акцента, в списке у выбранного — галочка (системный Picker внутри Menu).
    private var modeMenu: some View {
        Menu {
            Picker("Режим", selection: $mode) {
                ForEach(LLMChatMode.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Space.x1) {
                Image(systemName: mode.systemImage)
                Text(mode.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(DesignSystem.Typography.bodyBold(14))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Space.x3)
            .padding(.vertical, DesignSystem.Space.x1 + 2)
            .background(Capsule().fill(DesignSystem.Colors.accent))
            .contentShape(Capsule())
        }
        .disabled(isSending)
        .opacity(isSending ? 0.5 : 1)
        .accessibilityLabel("Режим: \(mode.title)")
        .accessibilityHint("Открывает список режимов чата")
    }

    // MARK: - Действия

    private var draftContext: TaskDraftContext {
        TaskDraftContext.make(groups: groups, tags: tags)
    }

    /// «План дня»: без задач — сообщение без запроса; перед первой отправкой — согласие (D-32).
    private func requestDayPlan() {
        guard !isSending else { return }
        if DayPlanService.selectTasks(allTasks).isEmpty {
            messages.append(LLMChatMessage(kind: .user(LLMChatMode.dayPlan.title)))
            messages.append(LLMChatMessage(kind: .info(DayPlanError.noTasks.userMessage)))
            return
        }
        if DayPlanService.hasConsent() {
            send(LLMChatMode.dayPlan.title, mode: .dayPlan)
        } else {
            showingDayPlanConsent = true
        }
    }

    /// «Матрица»: без задач без срока — сообщение без запроса; перед первой отправкой — согласие (D-42).
    private func requestMatrixReview() {
        guard !isSending else { return }
        if MatrixReviewService.selectTasks(allTasks).isEmpty {
            messages.append(LLMChatMessage(kind: .user(LLMChatMode.matrix.title)))
            messages.append(LLMChatMessage(kind: .info(MatrixReviewError.noTasks.userMessage)))
            return
        }
        if MatrixReviewService.hasConsent() {
            send(LLMChatMode.matrix.title, mode: .matrix)
        } else {
            showingMatrixConsent = true
        }
    }

    /// В «Итогах» `text` — период (`ReflectionPeriod.rawValue`), в «Плане дня» — подпись сообщения,
    /// а не ввод пользователя.
    private func send(_ text: String, mode: LLMChatMode) {
        guard !isSending, !text.isEmpty else { return }
        let period = mode == .reflection ? ReflectionPeriod(rawValue: text) : nil
        if mode == .reflection, period == nil { return }
        if mode == .task || mode == .inbox, text == trimmedInput {
            input = ""
        }
        messages.append(LLMChatMessage(kind: .user(period.map { "Итоги: \($0.title.lowercased())" } ?? text)))
        isSending = true
        let context = draftContext
        let stats = period.map { ReflectionService.compute(tasks: allTasks, habits: habits, period: $0) }
        let planTasks = mode == .dayPlan ? DayPlanService.selectTasks(allTasks) : []
        let matrixTasks = mode == .matrix ? MatrixReviewService.selectTasks(allTasks) : []
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
                case .reflection:
                    guard let stats else { return }
                    let text = try await ReflectionGenerator(provider: provider).reflection(for: stats)
                    messages.append(LLMChatMessage(kind: .reflection(text, stats: stats)))
                case .dayPlan:
                    let plan = try await DayPlanGenerator(provider: provider).plan(for: planTasks)
                    messages.append(LLMChatMessage(kind: .dayPlan(plan)))
                case .matrix:
                    let review = try await MatrixReviewGenerator(provider: provider).review(for: matrixTasks)
                    messages.append(LLMChatMessage(kind: .matrixReview(review)))
                }
            } catch {
                let message = (error as? LLMError)?.userMessage
                    ?? (error as? TaskDraftError)?.userMessage
                    ?? (error as? DayPlanError)?.userMessage
                    ?? (error as? MatrixReviewError)?.userMessage
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
