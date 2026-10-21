//
//  LLMProvider.swift
//  BraineeApp
//
//  Общие типы LLM (LLM-2): запрос, ответ, ошибки с понятными сообщениями.
//  Провайдер за протоколом — сценарии (LLM-3…) не зависят от OpenRouter напрямую.

import Foundation

protocol LLMProvider {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

struct LLMMessage: Equatable, Codable {
    enum Role: String, Codable {
        case system, user, assistant
    }

    let role: Role
    let content: String
}

struct LLMRequest: Equatable {
    var messages: [LLMMessage]
    /// Ограничение длины ответа — предсказуемая стоимость.
    var maxTokens: Int = 1024
    var temperature: Double? = 0.2
}

struct LLMResponse: Equatable {
    let text: String
    /// Модель, которая фактически ответила (для `openrouter/auto` — выбранная автоматически).
    let model: String?
}

enum LLMError: Error, Equatable {
    case missingKey
    case offline
    case timeout
    case invalidKey
    case insufficientCredits
    case rateLimited(retryAfterSeconds: Int?)
    case forbidden(String?)
    case modelNotFound(String)
    case modelUnavailable(String)
    case badRequest(String?)
    case server(Int)
    case emptyResponse
    /// Лимит ответа закончился раньше текста — обычно его съели скрытые рассуждения модели.
    case outputLimitReached(model: String?)
    case invalidResponse
    case unexpectedStatus(Int)
    case network(String)

    /// Текст для пользователя. Без ключа, тела запроса и заголовков.
    var userMessage: String {
        switch self {
        case .missingKey:
            return "Ключ OpenRouter не задан. Добавьте его в «Профиль → Настройки → LLM»."
        case .offline:
            return "Нет подключения к интернету. Проверьте сеть и повторите."
        case .timeout:
            return "OpenRouter не ответил за 30 секунд. Повторите позже."
        case .invalidKey:
            return "Ключ OpenRouter не принят: неверный, отключён или удалён. Замените ключ."
        case .insufficientCredits:
            return "Недостаточно средств на OpenRouter или исчерпан лимит ключа. Пополните баланс или выберите бесплатную модель (с суффиксом «:free»)."
        case .rateLimited(let seconds):
            if let seconds {
                return "Слишком много запросов. Повторите через \(seconds) с."
            }
            return "Слишком много запросов (у бесплатных моделей — 20 в минуту и дневной лимит). Повторите позже."
        case .forbidden(let message):
            return "Запрос отклонён OpenRouter" + Self.detail(message)
        case .modelNotFound(let model):
            return "Модель «\(model)» не найдена. Проверьте идентификатор в настройках LLM."
        case .modelUnavailable(let model):
            return "Модель «\(model)» сейчас недоступна. Повторите позже или выберите другую."
        case .badRequest(let message):
            return "Некорректный запрос" + Self.detail(message)
        case .server(let code):
            return "Сбой на стороне OpenRouter (код \(code)). Повторите позже."
        case .outputLimitReached(let model):
            let name = model.map { "«\($0)» " } ?? ""
            return "Модель \(name)израсходовала лимит ответа на размышления и не дописала ответ. Повторите или укажите в настройках LLM модель без рассуждений."
        case .emptyResponse:
            return "Модель вернула пустой ответ. Повторите или выберите другую модель."
        case .invalidResponse:
            return "Не удалось разобрать ответ OpenRouter."
        case .unexpectedStatus(let code):
            return "Неожиданный ответ OpenRouter (код \(code))."
        case .network(let description):
            return "Ошибка сети: \(description)"
        }
    }

    private static func detail(_ message: String?) -> String {
        guard let message, !message.isEmpty else { return "." }
        return ": \(message)"
    }
}
