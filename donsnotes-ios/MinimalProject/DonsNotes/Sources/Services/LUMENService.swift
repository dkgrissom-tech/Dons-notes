import Foundation
import AVFoundation
import Combine

// MARK: - LUMEN Insight (logged Q&A)
struct LUMENInsight: Identifiable, Codable {
    let id: UUID
    let question: String
    let answer: String
    let timestamp: Date

    init(question: String, answer: String) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.timestamp = Date()
    }
}

// MARK: - LUMEN Service
final class LUMENService: ObservableObject {

    // State
    @Published var orbState: LUMENOrbState = .idle
    @Published var isVoiceEnabled: Bool = true
    @Published var currentQuestion: String = ""
    @Published var currentAnswer: String = ""
    @Published var isShowingResponse: Bool = false
    @Published var insights: [LUMENInsight] = []
    @Published var isProcessing: Bool = false
    @Published var isAwake: Bool = false     // true after orb tap, waiting for question
    @Published var isShowingPaywall: Bool = false  // triggers PlansView sheet when free user tries AI

    // Trigger detection
    private let triggerWords = ["hey", "lumen"]

    // SpeechRecognizerService delivers the FULL cumulative transcript on every update,
    // so we track how many words we've already scanned and only look at new ones.
    private var lastProcessedWordCount: Int = 0
    private var alreadyTriggered: Bool = false

    // Cross-chunk lookback: keep the last word from the previous scan so a trigger split
    // as "...hey" then "lumen..." across two updates is still detected.
    private var tailBuffer: [String] = []

    // Question capture after the trigger fires.
    private var captureNextSentence: Bool = false
    private var questionBuffer: String = ""
    private var triggerDetectedAt: Date? = nil

    // Audio synthesis (ElevenLabs)
    private var audioPlayer: AVAudioPlayer?
    private let elevenLabsKey = Config.elevenLabsKey
    private let elevenLabsVoiceId = Config.elevenLabsVoiceId

    // Groq — free tier, OpenAI-compatible, zero cost per user
    private let groqKey = Config.groqKey
    private let groqModel = Config.groqModel

    private let voiceToggleKey = "lumen_voice_enabled"

    init() {
        isVoiceEnabled = UserDefaults.standard.object(forKey: voiceToggleKey) as? Bool ?? true
    }

    // MARK: - Voice Toggle
    func setVoiceEnabled(_ enabled: Bool) {
        isVoiceEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: voiceToggleKey)
    }

    // MARK: - Transcript Processing
    //
    // SIMPLE APPROACH: search the full lowercased transcript string for "lumen".
    // No word-splitting, no buffers, no punctuation stripping.
    // Works regardless of how Apple's speech engine formats the words.
    // We track what index we last found a trigger at so we don't fire twice.
    private var lastTriggerSearchIndex: String.Index? = nil

    func processTranscript(_ text: String, fullContext: String) {
        guard !text.isEmpty else { return }

        let lower = text.lowercased()

        // TAP-TO-WAKE: if orb was tapped, collect everything spoken after the tap.
        if isAwake {
            guard text.count > wakeTranscriptLength else { return }
            let question = String(text.dropFirst(wakeTranscriptLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if question.count > 3 {
                isAwake = false
                triggerQuestion(question: question, context: fullContext)
            }
            return
        }

        // If already capturing a question after hey-lumen trigger, collect new words.
        if captureNextSentence {
            // The question is everything after  "lumen" in the full transcript.
            if let range = lower.range(of: "lumen") {
                let afterTrigger = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if afterTrigger.count > 3 {
                    captureNextSentence = false
                    questionBuffer = ""
                    triggerQuestion(question: afterTrigger, context: fullContext)
                }
            }
            return
        }

        // Look for "lumen" anywhere in the transcript.
        // Only fire if we haven't already fired on this exact trigger position.
        if lower.contains("lumen") {
            // Make sure we haven't already handled this trigger.
            guard !alreadyTriggered else { return }
            alreadyTriggered = true

            Task { @MainActor in self.orbState = .triggered }

            // Collect what comes after "lumen" as the question.
            if let range = lower.range(of: "lumen") {
                let afterTrigger = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if afterTrigger.count > 3 {
                    triggerQuestion(question: afterTrigger, context: fullContext)
                } else {
                    // Question not in yet — wait for more transcript.
                    captureNextSentence = true
                    triggerDetectedAt = Date()
                    questionBuffer = ""
                    Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(0.8 * 1_000_000_000))
                        if self.captureNextSentence { self.orbState = .listening }
                    }
                }
            }
        }
    }

    // Abort question capture if nothing useful followed the trigger within 3s.
    func checkTriggerTimeout() {
        guard captureNextSentence, let triggeredAt = triggerDetectedAt else { return }
        if Date().timeIntervalSince(triggeredAt) > 3.0 &&
            questionBuffer.trimmingCharacters(in: .whitespaces).isEmpty {
            captureNextSentence = false
            questionBuffer = ""
            orbState = .listening
        }
    }

    // MARK: - Ask Claude
    func triggerQuestion(question: String, context: String) {
        guard !question.isEmpty else { return }
        // Paywall: LUMEN AI requires Lumen Pro or Lifetime
        guard SubscriptionService.shared.canUseLumenAI else {
            Task { @MainActor in
                self.orbState = .listening
                self.isAwake = false
                self.isShowingPaywall = true
            }
            return
        }
        Task { @MainActor in
            self.isProcessing = true
            self.currentQuestion = question
            self.orbState = .triggered      // thinking flash
        }

        Task {
            do {
                let answer = try await askGroq(question: question, context: context)
                await MainActor.run {
                    self.currentAnswer = answer
                    self.isShowingResponse = true
                    self.isProcessing = false
                    self.orbState = .responding   // speaking
                    let insight = LUMENInsight(question: question, answer: answer)
                    self.insights.insert(insight, at: 0)
                    if self.isVoiceEnabled {
                        // Say "I'm on it." then read the answer
                        Task {
                            await self.speak(text: "I'm on it.")
                            await self.speak(text: answer)
                        }
                    } else {
                        // No speech — return to listening shortly.
                        Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(0.6 * 1_000_000_000))
                            self.orbState = .listening
                        }
                    }
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.currentAnswer = "Error: \(msg)"
                    self.isShowingResponse = true
                    self.isProcessing = false
                    self.orbState = .listening
                }
            }
        }
    }

    // Manual ask (from post-meeting chat)
    func ask(question: String, context: String) async -> String {
        do {
            return try await askGroq(question: question, context: context)
        } catch {
            return "Lumen couldn't respond (\(error.localizedDescription)). Check your connection."
        }
    }

    // Groq API — OpenAI-compatible, free tier, no cost to you or the user
    private func askGroq(question: String, context: String) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = "You are LUMEN, an AI meeting assistant. Answer concisely in 2-3 sentences. Be direct and professional. Use the meeting transcript if provided, otherwise use general knowledge."
        let userMessage = context.isEmpty
            ? question
            : "Meeting transcript:\n\(context.prefix(3000))\n\nQuestion: \(question)"

        let body: [String: Any] = [
            "model": groqModel,
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "LUMENService", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Groq HTTP \(statusCode): \(bodyStr.prefix(200))"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return (message?["content"] as? String) ?? "I couldn't generate a response."
    }

    // MARK: - ElevenLabs TTS
    func speak(text: String) async {
        guard isVoiceEnabled else { return }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(elevenLabsVoiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(elevenLabsKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.8]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                await MainActor.run { self.orbState = .listening }
                return
            }

            // The recording session (SpeechRecognizerService) already owns .playAndRecord
            // with .defaultToSpeaker, so we just play through it without reconfiguring the
            // category — reconfiguring here would tear down the live recording tap.
            let player = try AVAudioPlayer(data: data)
            player.delegate = audioPlayerDelegate
            audioPlayerDelegate.onFinish = { [weak self] in
                Task { @MainActor in self?.orbState = .listening }
            }
            audioPlayer = player
            player.play()
        } catch {
            await MainActor.run { self.orbState = .listening }
        }
    }

    private lazy var audioPlayerDelegate: AudioPlayerEndDelegate = AudioPlayerEndDelegate()

    // Quick spoken acknowledgement when the trigger fires, before the answer is ready.
    // Called immediately when user taps the orb to wake LUMEN.
    func speakWake() {
        guard isVoiceEnabled else { return }
        Task { await speak(text: "Yes.") }
    }

    // Called just before delivering the answer.
    func speakAck() {
        guard isVoiceEnabled else { return }
        Task { await speak(text: "I'm on it.") }
    }

    func dismissResponse() {
        isShowingResponse = false
    }

    // Called when user taps the orb during recording.
    // Plays "Yes." and waits for them to speak their question.
    // isAwake is intentionally delayed 1.5s so the TTS audio ("Yes.") doesn't
    // bleed into the speech recogniser and get captured as the question.
    func orbTapped(currentTranscript: String) {
        guard orbState == .listening else { return }  // only wake when idle-listening
        orbState = .triggered
        speakWake()  // British guy says "Yes."
        // Delay activating question-capture until TTS has finished speaking (~1.5s)
        Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000)) [weak self] in
            guard let self = self else { return }
            // Snapshot transcript length HERE so we only capture words spoken after the beep
            self.wakeTranscriptLength = currentTranscript.count
            self.isAwake = true
            self.orbState = .listening
        }
    }

    // Transcript length at the moment the orb was tapped — question is everything after.
    private var wakeTranscriptLength: Int = 0

    func reset() {
        alreadyTriggered = false
        isAwake = false
        wakeTranscriptLength = 0
        lastProcessedWordCount = 0
        captureNextSentence = false
        questionBuffer = ""
        tailBuffer = []
        triggerDetectedAt = nil
        orbState = .idle
        isShowingResponse = false
    }
}

// MARK: - Audio Player Delegate (keeps AVAudioPlayer alive through playback)
private final class AudioPlayerEndDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
