import Foundation

/// Direct Groq API client. Replaces the Railway backend entirely.
/// Free tier: ~14,400 chat requests/day, ~7,200 transcription requests/day.
/// Free tier docs: https://console.groq.com/docs/rate-limits
enum GroqClient {

    // MARK: - Errors
    enum GroqError: LocalizedError {
        case missingAPIKey
        case rateLimited(retryAfter: TimeInterval?)
        case serviceUnavailable
        case badRequest(message: String)
        case decodingFailed
        case unknownStatus(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Groq API key not configured. Tap Settings → Connect Ora."
            case .rateLimited(let retry):
                if let r = retry { return "Ora is busy — try again in \(Int(r))s." }
                return "Ora is busy. Try again in a minute."
            case .serviceUnavailable:
                return "Ora's AI service is briefly down. Try again in a minute."
            case .badRequest(let msg):
                return "Request couldn't be processed: \(msg.prefix(120))"
            case .decodingFailed:
                return "Ora got an unexpected response. Try again."
            case .unknownStatus(let code, let msg):
                return "Ora error (\(code)): \(msg.prefix(120))"
            }
        }
    }

    // MARK: - Endpoints
    private static let chatURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private static let transcriptionURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    // MARK: - Chat (replaces askAI)

    struct ChatMessage: Codable {
        let role: String   // "system" | "user" | "assistant"
        let content: String
    }

    static func chat(messages: [ChatMessage],
                     model: String = Config.groqModel,
                     temperature: Double = 0.3,
                     timeoutSeconds: TimeInterval = 20) async throws -> String {
        let key = Config.groqKey
        guard !key.isEmpty else { throw GroqError.missingAPIKey }

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Codable {
            let model: String
            let messages: [ChatMessage]
            let temperature: Double
        }
        let body = Body(model: model, messages: messages, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let parsed = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let first = parsed.choices.first else {
            throw GroqError.decodingFailed
        }

        // Telemetry — increments local usage counter
        await GroqUsageTracker.shared.recordChatCall()

        return first.message.content
    }

    // MARK: - Transcription (replaces backend Whisper step)

    static func transcribe(audioURL: URL,
                           model: String = "whisper-large-v3-turbo",
                           timeoutSeconds: TimeInterval = 60) async throws -> String {
        let key = Config.groqKey
        guard !key.isEmpty else { throw GroqError.missingAPIKey }

        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: audioURL))
        body.append("\r\n".data(using: .utf8)!)
        // model part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        // response_format part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try Self.validate(response: response, data: data)

        // Groq returns plain text when response_format=text
        guard let transcript = String(data: data, encoding: .utf8) else {
            throw GroqError.decodingFailed
        }

        await GroqUsageTracker.shared.recordTranscriptionCall()

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Shared response validator

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GroqError.serviceUnavailable
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw GroqError.missingAPIKey
        case 429:
            let retry = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw GroqError.rateLimited(retryAfter: retry)
        case 500, 502, 503, 504:
            throw GroqError.serviceUnavailable
        case 400, 422:
            let msg = String(data: data, encoding: .utf8) ?? "bad request"
            throw GroqError.badRequest(message: msg)
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw GroqError.unknownStatus(code: http.statusCode, message: msg)
        }
    }
}
