import Foundation

/// Tracks per-day Groq API usage on device. Resets at midnight local time.
/// Shown in Settings so you can spot abuse or near-rate-limit conditions.
actor GroqUsageTracker {
    static let shared = GroqUsageTracker()

    private let chatKey = "groq_chat_calls_today"
    private let transcriptionKey = "groq_transcription_calls_today"
    private let dateKey = "groq_usage_date"

    private func resetIfNewDay() {
        let today = ISO8601DateFormatter.dateOnly.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: dateKey)
        if stored != today {
            UserDefaults.standard.set(today, forKey: dateKey)
            UserDefaults.standard.set(0, forKey: chatKey)
            UserDefaults.standard.set(0, forKey: transcriptionKey)
        }
    }

    func recordChatCall() {
        resetIfNewDay()
        let n = UserDefaults.standard.integer(forKey: chatKey) + 1
        UserDefaults.standard.set(n, forKey: chatKey)
    }

    func recordTranscriptionCall() {
        resetIfNewDay()
        let n = UserDefaults.standard.integer(forKey: transcriptionKey) + 1
        UserDefaults.standard.set(n, forKey: transcriptionKey)
    }

    func todayCounts() -> (chat: Int, transcription: Int) {
        resetIfNewDay()
        return (
            UserDefaults.standard.integer(forKey: chatKey),
            UserDefaults.standard.integer(forKey: transcriptionKey)
        )
    }
}

private extension ISO8601DateFormatter {
    static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
