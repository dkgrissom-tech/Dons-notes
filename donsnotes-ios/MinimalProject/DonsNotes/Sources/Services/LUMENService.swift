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
    @Published var debugLog: String = ""  // visible on screen during recording — remove before App Store

    private func dbg(_ msg: String) {
        let ts = String(format: "%.1f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
        Task { @MainActor in
            self.debugLog = "[\(ts)] \(msg)\n" + self.debugLog.components(separatedBy: "\n").prefix(6).joined(separator: "\n")
        }
    }

    // Trigger detection
    private let triggerWords = ["hey", "ora"]

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
    // Character offset of the END of the last "ora" match we already handled.
    // We only look for new "ora" occurrences AFTER this position so the cumulative
    // transcript can't re-fire the same trigger.
    private var lastTriggerCharIndex: Int = 0

    // Silence-based endpointing for the question after "Lumen" trigger.
    // Wait this long after the LAST transcript update before sending the question.
    private let silenceWaitSeconds: Double = 2.5

    // Minimum question length in characters before we'll even consider sending.
    private let minQuestionChars: Int = 8

    // Hard ceiling — if user has been talking continuously past this, just send.
    private let maxQuestionSeconds: Double = 15.0

    // Tracks the last time we saw a transcript update after the trigger fired.
    private var lastQuestionUpdateAt: Date? = nil
    private var pendingQuestion: String = ""
    private var pendingContext: String = ""
    private var silenceFireTask: Task<Void, Never>? = nil

    func processTranscript(_ text: String, fullContext: String) {
        guard !text.isEmpty else { return }

        let lower = text.lowercased()

        // TAP-TO-WAKE: if orb was tapped, collect everything spoken after the wake timestamp.
        if isAwake {
            guard let wakeTime = wakeTimestamp,
                  Date().timeIntervalSince(wakeTime) > 0 else { return }

            // Strip the transcript content that existed at tap time.
            // If the recognizer reset and the transcript is now SHORTER than our
            // snapshot, the new content is entirely post-tap — use all of it.
            let question: String
            if text.count > wakeTranscriptSnapshot.count && text.hasPrefix(wakeTranscriptSnapshot) {
                // Normal case: transcript grew past snapshot
                question = String(text.dropFirst(wakeTranscriptSnapshot.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if text.count <= wakeTranscriptSnapshot.count {
                // Recognizer reset — the whole new transcript is post-tap
                question = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Transcript grew but doesn't share prefix — use everything after snapshot length
                question = String(text.dropFirst(min(wakeTranscriptSnapshot.count, text.count)))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if question.count >= minQuestionChars {
                bufferQuestionAndWaitForSilence(question: question, context: fullContext)
            }
            return
        }

        // If we already fired a trigger and are waiting for the question, accumulate it.
        if captureNextSentence {
            accumulatePostTriggerQuestion(text, fullContext: fullContext)
            return
        }

        // Look for a NEW "ora" trigger — one that appears AFTER the last trigger position.
        // lastTriggerCharIndex advances each time so the cumulative transcript never re-fires.
        let searchStart = lower.index(lower.startIndex, offsetBy: min(lastTriggerCharIndex, lower.count))
        let searchSlice = lower[searchStart...]

        guard let range = searchSlice.range(of: "ora") else { return }

        // Mark the end of this trigger so future calls skip past it.
        let newTriggerEnd = lower.distance(from: lower.startIndex, to: range.upperBound)
        lastTriggerCharIndex = newTriggerEnd

        Task { @MainActor in self.orbState = .triggered }

        // Everything after "ora" in the original text is the start of the question.
        let origStart = text.index(text.startIndex, offsetBy: min(newTriggerEnd, text.count))
        let afterTrigger = String(text[origStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if afterTrigger.count > 3 {
            dbg("ORA+Q(\(afterTrigger.count)ch): \(afterTrigger.prefix(25))")
            bufferQuestionAndWaitForSilence(question: afterTrigger, context: fullContext)
        } else {
            dbg("ORA alone -> captureNextSentence")
            captureNextSentence = true
            triggerDetectedAt = Date()
        }
    }

    // Called from the transcript observer when captureNextSentence is true.
    // Accumulates everything spoken after the trigger and fires via silence buffer.
    private func accumulatePostTriggerQuestion(_ text: String, fullContext: String) {
        guard captureNextSentence else { return }
        let origStart = text.index(text.startIndex, offsetBy: min(lastTriggerCharIndex, text.count))
        let afterTrigger = String(text[origStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard afterTrigger.count > 3 else { return }
        // Feed into silence buffer — it will fire after silenceWaitSeconds of quiet.
        bufferQuestionAndWaitForSilence(question: afterTrigger, context: fullContext)
    }

    // Buffer the latest partial and (re)start a silence countdown.
    // Each time a new partial arrives, we reset the timer.
    // When the user actually stops talking for `silenceWaitSeconds`, we fire.
    private func bufferQuestionAndWaitForSilence(question: String, context: String) {
        pendingQuestion = question
        pendingContext = context
        lastQuestionUpdateAt = Date()

        // Cancel any previously scheduled fire — we got a new word.
        silenceFireTask?.cancel()
        silenceFireTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.silenceWaitSeconds * 1_000_000_000))
            if Task.isCancelled { return }
            await self.fireBufferedQuestionIfReady()
        }
    }

    @MainActor
    private func fireBufferedQuestionIfReady() async {
        guard !pendingQuestion.isEmpty else { return }

        let q = pendingQuestion
        let ctx = pendingContext

        // Reset state BEFORE firing so a late partial doesn't double-send.
        captureNextSentence = false
        isAwake = false
        pendingQuestion = ""
        pendingContext = ""
        questionBuffer = ""
        triggerDetectedAt = nil
        lastQuestionUpdateAt = nil

        triggerQuestion(question: q, context: ctx)
    }

    // Abort question capture only if NOTHING was ever heard within 8s of the trigger.
    func checkTriggerTimeout() {
        guard captureNextSentence, let triggeredAt = triggerDetectedAt else { return }

        // Long ceiling — user is rambling, send what we have.
        if let updated = lastQuestionUpdateAt,
           Date().timeIntervalSince(triggeredAt) > maxQuestionSeconds,
           !pendingQuestion.isEmpty {
            silenceFireTask?.cancel()
            Task { @MainActor in await fireBufferedQuestionIfReady() }
            return
        }

        // True silence — they never said anything after "lumen". Bail.
        if Date().timeIntervalSince(triggeredAt) > 8.0 &&
            pendingQuestion.isEmpty &&
            questionBuffer.trimmingCharacters(in: .whitespaces).isEmpty {
            captureNextSentence = false
            questionBuffer = ""
            orbState = .listening
        }
    }

    // MARK: - Ask Claude
    func triggerQuestion(question: String, context: String) {
        guard !question.isEmpty else { return }
        // Paywall: LUMEN AI requires Ora Pro or Lifetime
        guard SubscriptionService.shared.canUseOraAI else {
            Task { @MainActor in
                self.orbState = .listening
                self.isAwake = false
                self.isShowingPaywall = true
            }
            return
        }

        // Reset trigger state so Ora can be called again in the same session.
        // Note: lastTriggerCharIndex is intentionally NOT reset here — it marks how far
        // into the cumulative transcript we've already processed, preventing the same
        // "ora" word from re-firing after the response completes.
        alreadyTriggered = false
        captureNextSentence = false
        isAwake = false
        questionBuffer = ""
        triggerDetectedAt = nil
        lastQuestionUpdateAt = nil

        dbg("GROQ->: \(question.prefix(30))")
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
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: UInt64(0.6 * 1_000_000_000))
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
            return "Ora couldn't respond (\(error.localizedDescription)). Check your connection."
        }
    }

    // Groq API — OpenAI-compatible, free tier, no cost to you or the user
    private func askGroq(question: String, context: String) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = "You are ORA, an AI meeting assistant. Answer concisely in 2-3 sentences. Be direct and professional. Use the meeting transcript if provided, otherwise use general knowledge."
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

            // SpeechRecognizerService already owns AVAudioSession as .playAndRecord
            // + .defaultToSpeaker — do NOT reconfigure it here. Calling setCategory
            // mid-recognition tears down the engine tap and kills the transcript.
            // AVAudioPlayer routes through the existing session automatically.
            let player = try AVAudioPlayer(data: data)
            player.delegate = audioPlayerDelegate
            audioPlayerDelegate.onFinish = { [weak self] in
                Task { @MainActor in self?.orbState = .listening }
            }
            audioPlayer = player
            player.prepareToPlay()
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
        // Allow tap when listening OR after a response finishes (responding/triggered).
        // Only block if already awake waiting for a question.
        guard !isAwake, !isProcessing else { return }
        orbState = .triggered
        speakWake()  // British guy says "Yes."
        // Delay activating question-capture until TTS has finished speaking (~1.5s)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            guard let self = self else { return }
            // Snapshot the transcript TEXT (not just length) at this exact moment.
            // This handles recognizer resets — if transcript shrinks post-tap we
            // still know what was there before and treat everything new as the question.
            self.wakeTranscriptSnapshot = currentTranscript
            self.wakeTranscriptLength = currentTranscript.count  // kept for reset()
            self.wakeTimestamp = Date()
            self.isAwake = true
            self.orbState = .listening
        }
    }

    // Timestamp of when the orb was tapped — we ignore ANY transcript content
    // that arrives before this moment, so TTS bleed and recognizer resets don't matter.
    // We also track the transcript text that existed at tap time so we can strip it.
    private var wakeTimestamp: Date? = nil
    private var wakeTranscriptSnapshot: String = ""
    private var wakeTranscriptLength: Int = 0  // kept for reset()

    func reset() {
        alreadyTriggered = false
        isAwake = false
        wakeTranscriptLength = 0
        wakeTranscriptSnapshot = ""
        wakeTimestamp = nil
        lastProcessedWordCount = 0
        lastTriggerCharIndex = 0
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
