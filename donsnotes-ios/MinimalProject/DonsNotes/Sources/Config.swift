import Foundation

// MARK: - Config
// API keys are injected via Config.xcconfig (local dev) or
// environment variables during CI build.
// Config.xcconfig is in .gitignore — never commit keys to source control.
enum Config {
    // MARK: ElevenLabs
    static let elevenLabsKey: String = {
        // In CI: injected via environment variable into xcconfig
        if let key = Bundle.main.infoDictionary?["ELEVENLABS_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return ""
    }()

    static let elevenLabsVoiceId: String = {
        if let id = Bundle.main.infoDictionary?["ELEVENLABS_VOICE_ID"] as? String,
           !id.isEmpty, !id.hasPrefix("$(") {
            return id
        }
        return "onwK4e9ZLuTAKqWW03F9" // Daniel — British male broadcaster
    }()

    // MARK: Groq (free tier — replaces Anthropic, zero cost per user)
    // Free at console.groq.com — no charges regardless of user count
    static let groqKey: String = {
        if let key = Bundle.main.infoDictionary?["GROQ_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return ""
    }()

    // llama-3.3-70b-versatile: best free Groq model for Q&A
    static let groqModel = "llama-3.3-70b-versatile"
}
