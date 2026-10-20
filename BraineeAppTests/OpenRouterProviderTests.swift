//
//  OpenRouterProviderTests.swift
//  BraineeAppTests
//
//  LLM-2: запросы к OpenRouter через URLProtocol-заглушку — без сети и без настоящего ключа.

import Foundation
import Testing
@testable import BraineeApp

/// Подменяет ответы URLSession. Обработчик общий, поэтому набор тестов выполняется последовательно.
final class StubURLProtocol: URLProtocol {
    enum Reply {
        case http(status: Int, body: String, headers: [String: String] = [:])
        case failure(URLError.Code)
    }

    nonisolated(unsafe) static var handler: ((URLRequest) -> Reply)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func makeSession(_ handler: @escaping (URLRequest) -> Reply) -> URLSession {
        self.handler = handler
        requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Тело запроса: URLSession передаёт его в протокол потоком, а не в `httpBody`.
    static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        guard let reply = Self.handler?(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        switch reply {
        case .http(let status, let body, let headers):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct OpenRouterProviderTests {
    private let testKey = "sk-or-test-stub-0000"
    private let model = "test/model"

    private static let completionOK = """
    {"id":"gen-1","model":"test/model-v2","choices":[{"message":{"role":"assistant","content":"  Привет  "}}]}
    """
    private static let keyInfoOK = """
    {"data":{"label":"sk-or-v1-abc...","limit":5,"limit_remaining":3.2,"usage":1.8,"usage_daily":0.04,
    "is_free_tier":false,"free_model_daily_requests":{"used":5,"limit":50,"remaining":45}}}
    """

    private func provider(_ handler: @escaping (URLRequest) -> StubURLProtocol.Reply) -> OpenRouterProvider {
        OpenRouterProvider(apiKey: testKey, model: model, session: StubURLProtocol.makeSession(handler))
    }

    private func request() -> LLMRequest {
        LLMRequest(messages: [LLMMessage(role: .user, content: "Купить молоко завтра")])
    }

    private func expectError(
        _ expected: LLMError,
        reply: StubURLProtocol.Reply,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        do {
            _ = try await provider { _ in reply }.complete(request())
            Issue.record("Ожидалась ошибка \(expected)", sourceLocation: sourceLocation)
        } catch let error as LLMError {
            #expect(error == expected, sourceLocation: sourceLocation)
        } catch {
            Issue.record("Не LLMError: \(error)", sourceLocation: sourceLocation)
        }
    }

    // Успешный ответ: текст без пробелов по краям и модель, которая фактически ответила.
    @Test func успешныйОтвет_текстИМодель() async throws {
        let response = try await provider { _ in .http(status: 200, body: Self.completionOK) }.complete(request())
        #expect(response.text == "Привет")
        #expect(response.model == "test/model-v2")
    }

    // Запрос: POST на /chat/completions, ключ только в Authorization, тайм-аут 30 с, в теле — модель, сообщения, лимит токенов.
    @Test func запрос_адресЗаголовкиТело() async throws {
        _ = try await provider { _ in .http(status: 200, body: Self.completionOK) }.complete(request())
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer \(testKey)")
        #expect(sent.timeoutInterval == 30)

        let body = try #require(StubURLProtocol.body(of: sent))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == model)
        #expect(json["max_tokens"] as? Int == 1024)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["role"] as? String == "user")
        #expect(messages.first?["content"] as? String == "Купить молоко завтра")
        #expect(String(decoding: body, as: UTF8.self).contains(testKey) == false)
    }

    // Коды HTTP → понятные ошибки.
    @Test func кодыHTTP_соответствующиеОшибки() async {
        await expectError(.invalidKey, reply: .http(status: 401, body: #"{"error":{"code":401,"message":"No auth credentials found"}}"#))
        await expectError(.insufficientCredits, reply: .http(status: 402, body: #"{"error":{"code":402,"message":"Insufficient credits"}}"#))
        await expectError(.forbidden("Flagged"), reply: .http(status: 403, body: #"{"error":{"code":403,"message":"Flagged"}}"#))
        await expectError(.modelNotFound(model), reply: .http(status: 404, body: #"{"error":{"code":404,"message":"No endpoints found"}}"#))
        await expectError(.modelNotFound(model), reply: .http(status: 400, body: #"{"error":{"code":400,"message":"test/model is not a valid model ID"}}"#))
        await expectError(.badRequest("max_tokens must be positive"), reply: .http(status: 400, body: #"{"error":{"code":400,"message":"max_tokens must be positive"}}"#))
        await expectError(.timeout, reply: .http(status: 408, body: "{}"))
        await expectError(.modelUnavailable(model), reply: .http(status: 502, body: "{}"))
        await expectError(.modelUnavailable(model), reply: .http(status: 503, body: "{}"))
        await expectError(.server(500), reply: .http(status: 500, body: "oops"))
        await expectError(.unexpectedStatus(418), reply: .http(status: 418, body: ""))
    }

    // 429: время ожидания берётся из Retry-After, если сервер его прислал.
    @Test func лимитЗапросов_retryAfter() async {
        await expectError(.rateLimited(retryAfterSeconds: 12), reply: .http(status: 429, body: "{}", headers: ["Retry-After": "12"]))
        await expectError(.rateLimited(retryAfterSeconds: nil), reply: .http(status: 429, body: "{}"))
    }

    // Ошибки сети: нет интернета, тайм-аут, прочее.
    @Test func ошибкиСети_нетСетиТаймаутПрочее() async {
        await expectError(.offline, reply: .failure(.notConnectedToInternet))
        await expectError(.offline, reply: .failure(.cannotFindHost))
        await expectError(.timeout, reply: .failure(.timedOut))
        await expectError(.network(URLError(.badServerResponse).localizedDescription), reply: .failure(.badServerResponse))
    }

    // Невалидный JSON, ответ без вариантов, пустой текст.
    @Test func плохойОтвет_ошибкаРазбораИлиПустойОтвет() async {
        await expectError(.invalidResponse, reply: .http(status: 200, body: "<html>"))
        await expectError(.invalidResponse, reply: .http(status: 200, body: #"{"choices":[]}"#))
        await expectError(.emptyResponse, reply: .http(status: 200, body: #"{"choices":[{"message":{"content":"   "}}]}"#))
        await expectError(.emptyResponse, reply: .http(status: 200, body: #"{"choices":[{"message":{"content":null}}]}"#))
    }

    // Ошибка после начала генерации: код 200, объект `error` в теле.
    @Test func ошибкаВТелеПриКоде200_распознаётся() async {
        await expectError(.modelUnavailable(model), reply: .http(status: 200, body: #"{"error":{"code":502,"message":"Provider returned error"}}"#))
    }

    // Длинное сообщение сервера обрезается до 200 символов.
    @Test func длинноеСообщениеСервера_обрезается() async {
        let long = String(repeating: "x", count: 500)
        await expectError(.forbidden(String(repeating: "x", count: 200)), reply: .http(status: 403, body: #"{"error":{"message":"\#(long)"}}"#))
    }

    // GET /key: остаток, расход за день, счётчик бесплатных моделей.
    @Test func информацияОКлюче_разбираетсяИФорматируется() async throws {
        let info = try await provider { _ in .http(status: 200, body: Self.keyInfoOK) }.fetchKeyInfo()
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.httpMethod == "GET")
        #expect(sent.url?.absoluteString == "https://openrouter.ai/api/v1/key")
        #expect(info.limitRemaining == 3.2)
        #expect(info.usageDaily == 0.04)
        #expect(info.summary == "Осталось $3.20 · сегодня $0.04")
        #expect(info.freeModelsSummary == "Бесплатные модели: осталось 45 из 50 запросов сегодня")
    }

    // Ключ без лимита: limit_remaining = null.
    @Test func ключБезЛимита_понятнаяСтрока() async throws {
        let body = #"{"data":{"limit":null,"limit_remaining":null,"usage":0.5,"usage_daily":0.004}}"#
        let info = try await provider { _ in .http(status: 200, body: body) }.fetchKeyInfo()
        #expect(info.summary == "Лимит ключа не задан · сегодня <$0.01")
        #expect(info.freeModelsSummary == nil)
    }

    // Неверный ключ при запросе /key — та же ошибка, что и при запросе к модели.
    @Test func информацияОКлюче_неверныйКлюч() async {
        do {
            _ = try await provider { _ in .http(status: 401, body: "{}") }.fetchKeyInfo()
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? LLMError == .invalidKey)
        }
    }

    // Проверка соединения: сначала /key, затем короткий запрос к модели; пустой ответ модели — не ошибка.
    @Test func проверкаСоединения_ключИМодель() async throws {
        let report = try await provider { request in
            request.url?.lastPathComponent == "key"
                ? .http(status: 200, body: Self.keyInfoOK)
                : .http(status: 200, body: #"{"model":"test/model-v2","choices":[{"message":{"content":""}}]}"#)
        }.checkConnection()
        #expect(StubURLProtocol.requests.map { $0.url?.lastPathComponent } == ["key", "completions"])
        #expect(report.model == "test/model-v2")
        #expect(report.keyInfo.limitRemaining == 3.2)
    }

    // Проверка соединения с недоступной моделью: ключ в порядке, но модель не найдена.
    @Test func проверкаСоединения_модельНеНайдена() async {
        do {
            _ = try await provider { request in
                request.url?.lastPathComponent == "key"
                    ? .http(status: 200, body: Self.keyInfoOK)
                    : .http(status: 404, body: "{}")
            }.checkConnection()
            Issue.record("Ожидалась ошибка")
        } catch {
            #expect(error as? LLMError == .modelNotFound(model))
        }
    }

    // Без ключа в Keychain провайдер не создаётся.
    @Test func безКлюча_ошибкаMissingKey() {
        let secrets = SecretStore(service: "BraineeAppTests.secrets.\(UUID().uuidString)")
        #expect(throws: LLMError.missingKey) {
            try OpenRouterProvider.fromSettings(secrets: secrets)
        }
    }

    // Сообщения об ошибках не содержат ключ.
    @Test func сообщенияОбОшибках_безКлюча() {
        let errors: [LLMError] = [
            .missingKey, .offline, .timeout, .invalidKey, .insufficientCredits,
            .rateLimited(retryAfterSeconds: 5), .forbidden(nil), .modelNotFound(model),
            .modelUnavailable(model), .badRequest("x"), .server(500), .emptyResponse,
            .invalidResponse, .unexpectedStatus(418), .network("x")
        ]
        for error in errors {
            #expect(!error.userMessage.isEmpty)
            #expect(!error.userMessage.contains(testKey))
        }
    }
}
