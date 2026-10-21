//
//  OpenRouterProvider.swift
//  BraineeApp
//
//  OpenRouter по HTTPS (LLM-2, D-24): `POST /chat/completions`, `GET /key` (остаток лимита ключа).
//  Ключ — только в заголовке Authorization; ничего не логируется.

import Foundation

struct OpenRouterProvider: LLMProvider {
    static let baseURL = URL(string: "https://openrouter.ai/api/v1")!
    static let timeout: TimeInterval = 30
    /// Максимум символов сообщения об ошибке от сервера, показываемого пользователю.
    static let maxErrorMessageLength = 200

    let apiKey: String
    let model: String
    var session: URLSession = .shared

    /// Провайдер из настроек: ключ из Keychain, модель из UserDefaults.
    static func fromSettings(
        secrets: SecretStore = .shared,
        defaults: UserDefaults = .standard,
        session: URLSession = .shared
    ) throws -> OpenRouterProvider {
        guard let key = secrets.value(for: .openRouterAPIKey) else { throw LLMError.missingKey }
        return OpenRouterProvider(apiKey: key, model: LLMSettings.model(defaults: defaults), session: session)
    }

    // MARK: - Chat completions

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let body = try await chatCompletion(request)
        let choice = body.choices?.first
        guard let text = choice?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            // Рассуждающие модели (в том числе выбранные `openrouter/auto`) могут потратить весь
            // max_tokens на скрытые рассуждения: тогда текста нет, а finish_reason = "length".
            if choice?.finish_reason == "length" { throw LLMError.outputLimitReached(model: body.model) }
            throw LLMError.emptyResponse
        }
        return LLMResponse(text: text, model: body.model)
    }

    private func chatCompletion(_ request: LLMRequest) async throws -> ChatCompletionBody {
        var urlRequest = makeRequest(path: "chat/completions")
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
            model: model,
            messages: request.messages,
            max_tokens: Self.effectiveMaxTokens(request.maxTokens, model: model),
            temperature: request.temperature,
            reasoning: .init(effort: "low", exclude: true)
        ))
        let data = try await send(urlRequest)
        guard let body = try? JSONDecoder().decode(ChatCompletionBody.self, from: data) else {
            throw LLMError.invalidResponse
        }
        // Ошибка после начала генерации приходит с кодом 200 и объектом `error` в теле.
        if let error = body.error {
            throw Self.error(status: error.code ?? 502, message: error.message, model: model, retryAfter: nil)
        }
        guard body.choices?.isEmpty == false else { throw LLMError.invalidResponse }
        return body
    }

    /// Бесплатные модели (`openrouter/free`, `…:free`) сейчас все рассуждающие, и большинство не понимает
    /// `reasoning.effort`: рассуждения съедают лимит ответа. Платить за них не нужно, поэтому лимит ×4.
    static let freeModelTokenMultiplier = 4

    static func isFreeModel(_ model: String) -> Bool {
        model == "openrouter/free" || model.hasSuffix(":free")
    }

    static func effectiveMaxTokens(_ requested: Int, model: String) -> Int {
        isFreeModel(model) ? requested * freeModelTokenMultiplier : requested
    }

    // MARK: - Key info

    /// Лимиты и расход текущего ключа. Бесплатный запрос, проверяет и сам ключ.
    func fetchKeyInfo() async throws -> OpenRouterKeyInfo {
        let data = try await send(makeRequest(path: "key"))
        guard let info = try? JSONDecoder().decode(KeyInfoBody.self, from: data).data else {
            throw LLMError.invalidResponse
        }
        return info
    }

    // MARK: - Connection check

    /// «Проверить соединение»: ключ и лимит (`/key`), затем короткий запрос к выбранной модели.
    /// Пустой ответ модели здесь не ошибка: важно, что модель доступна.
    func checkConnection() async throws -> LLMConnectionReport {
        let keyInfo = try await fetchKeyInfo()
        let body = try await chatCompletion(LLMRequest(
            messages: [LLMMessage(role: .user, content: "ping")],
            maxTokens: 16,
            temperature: 0
        ))
        return LLMConnectionReport(model: body.model ?? model, keyInfo: keyInfo)
    }

    // MARK: - Transport

    private func makeRequest(path: String) -> URLRequest {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path), timeoutInterval: Self.timeout)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("BraineeApp", forHTTPHeaderField: "X-Title")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.error(transport: error)
        }
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw Self.error(status: http.statusCode, message: message, model: model, retryAfter: retryAfter)
        }
        return data
    }

    // MARK: - Error mapping

    static func error(transport error: Error) -> LLMError {
        guard let urlError = error as? URLError else { return .network(error.localizedDescription) }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .network(urlError.localizedDescription)
        }
    }

    static func error(status: Int, message: String?, model: String, retryAfter: Int?) -> LLMError {
        let message = message.map { String($0.prefix(maxErrorMessageLength)) }
        switch status {
        case 400:
            if let message, message.localizedCaseInsensitiveContains("model") {
                return .modelNotFound(model)
            }
            return .badRequest(message)
        case 401:
            return .invalidKey
        case 402:
            return .insufficientCredits
        case 403:
            return .forbidden(message)
        case 404:
            return .modelNotFound(model)
        case 408:
            return .timeout
        case 429:
            return .rateLimited(retryAfterSeconds: retryAfter)
        case 502, 503:
            return .modelUnavailable(model)
        case 500...599:
            return .server(status)
        default:
            return .unexpectedStatus(status)
        }
    }

    // MARK: - Wire format

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [LLMMessage]
        let max_tokens: Int
        let temperature: Double?
        /// Меньше скрытых рассуждений — больше лимита на сам ответ; рассуждения в ответ не включаются.
        /// Модели без рассуждений этот параметр игнорируют.
        let reasoning: Reasoning

        struct Reasoning: Encodable {
            let effort: String
            let exclude: Bool
        }
    }

    private struct ChatCompletionBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message?
            let finish_reason: String?
        }
        let model: String?
        let choices: [Choice]?
        let error: ErrorBody?
    }

    private struct ErrorBody: Decodable {
        let code: Int?
        let message: String?
    }

    private struct ErrorEnvelope: Decodable {
        let error: ErrorBody
    }

    private struct KeyInfoBody: Decodable {
        let data: OpenRouterKeyInfo
    }
}

/// Ответ `GET /api/v1/key` (нужные поля). Суммы — в долларах (кредиты OpenRouter).
struct OpenRouterKeyInfo: Equatable, Decodable {
    struct FreeModelRequests: Equatable, Decodable {
        let used: Int?
        let limit: Int?
        let remaining: Int?
    }

    let limit: Double?
    let limitRemaining: Double?
    let usage: Double?
    let usageDaily: Double?
    let isFreeTier: Bool?
    let freeModelDailyRequests: FreeModelRequests?

    enum CodingKeys: String, CodingKey {
        case limit
        case limitRemaining = "limit_remaining"
        case usage
        case usageDaily = "usage_daily"
        case isFreeTier = "is_free_tier"
        case freeModelDailyRequests = "free_model_daily_requests"
    }

    init(
        limit: Double? = nil,
        limitRemaining: Double? = nil,
        usage: Double? = nil,
        usageDaily: Double? = nil,
        isFreeTier: Bool? = nil,
        freeModelDailyRequests: FreeModelRequests? = nil
    ) {
        self.limit = limit
        self.limitRemaining = limitRemaining
        self.usage = usage
        self.usageDaily = usageDaily
        self.isFreeTier = isFreeTier
        self.freeModelDailyRequests = freeModelDailyRequests
    }

    /// «Осталось $3.20 · сегодня $0.04»; без лимита ключа — «Лимит ключа не задан · сегодня $0.04».
    var summary: String {
        let remaining = limitRemaining.map { "Осталось \(Self.dollars($0))" } ?? "Лимит ключа не задан"
        guard let usageDaily else { return remaining }
        return "\(remaining) · сегодня \(Self.dollars(usageDaily))"
    }

    /// «Бесплатные модели: осталось 45 из 50 запросов сегодня» — если OpenRouter вернул счётчик.
    var freeModelsSummary: String? {
        guard let remaining = freeModelDailyRequests?.remaining else { return nil }
        if let limit = freeModelDailyRequests?.limit {
            return "Бесплатные модели: осталось \(remaining) из \(limit) запросов сегодня"
        }
        return "Бесплатные модели: осталось \(remaining) запросов сегодня"
    }

    static func dollars(_ value: Double) -> String {
        if value > 0, value < 0.01 { return "<$0.01" }
        return "$" + String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

struct LLMConnectionReport: Equatable {
    let model: String
    let keyInfo: OpenRouterKeyInfo
}
