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
        return "EXAVITQu4vr4xnSDxMaL" // Bella — fallback default
    }()

    // MARK: Anthropic / Claude
    static let claudeKey: String = {
        if let key = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return ""
    }()

    static let claudeModel = "claude-3-5-haiku-20241022"
}
