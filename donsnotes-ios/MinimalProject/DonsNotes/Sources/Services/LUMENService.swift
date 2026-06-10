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
class LUMENService: ObservableObject {
    
    // State
    @Published var orbState: LUMENOrbState = .idle
    @Published var isVoiceEnabled: Bool = true   // toggle: voice or text-only
    @Published var currentQuestion: String = ""
    @Published var currentAnswer: String = ""
    @Published var isShowingResponse: Bool = false
    @Published var insights: [LUMENInsight] = []
    @Published var isProcessing: Bool = false
    
    // Trigger detection
    private let triggerPhrase = "hey lumen"
    private var lastProcessedWordCount: Int = 0   // how many words we've already scanned
    private var captureNextSentence: Bool = false
    private var pendingQuestion: String = ""
    private var questionBuffer: String = ""
    private var triggerDetectedAt: Date? = nil

    // ── FIX: rolling lookback for cross-chunk trigger detection ──────────────
    // iOS speech recognition delivers partial results in chunks. "Hey," may arrive
    // in one chunk and "Lumen." in the next. The old sliding-window only examined
    // NEW words in the current chunk, so a trigger split across chunks was missed.
    // We keep the last 2 cleaned words from the previous chunk and prepend them
    // when building the window for the current chunk.
    private var previousChunkTailWords: [String] = []
    
    // Audio synthesis (ElevenLabs)
    private var audioPlayer: AVAudioPlayer?
    private let elevenLabsKey = Config.elevenLabsKey
    private let elevenLabsVoiceId = Config.elevenLabsVoiceId
    
    // Claude API
    private let claudeKey = Config.claudeKey
    
    // Voice toggle persistence
    private let voiceToggleKey = "lumen_voice_enabled"
    
    init() {
        isVoiceEnabled = UserDefaults.standard.object(forKey: voiceToggleKey) as? Bool ?? true
    }
    
    // MARK: - Voice Toggle
    func setVoiceEnabled(_ enabled: Bool) {
        isVoiceEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: voiceToggleKey)
    }
    
    // MARK: - Transcript Processing (called every time transcript updates)
    // transcript is the FULL cumulative text from SpeechRecognizerService (never resets).
    func processTranscript(_ transcript: String, fullContext: String) {
        // Break into words and only look at NEW words since last call
        let allWords = transcript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard allWords.count > lastProcessedWordCount else { return }

        let newWords = Array(allWords[lastProcessedWordCount...])
        lastProcessedWordCount = allWords.count

        guard !newWords.isEmpty else { return }

        if captureNextSentence {
            // Strip punctuation per-word and join for clean question text
            let cleanNewText = newWords
                .map { wordStrippingAllPunctuation($0).lowercased() }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !cleanNewText.isEmpty else { return }

            questionBuffer += questionBuffer.isEmpty ? cleanNewText : " " + cleanNewText
            let trimmed = questionBuffer.trimmingCharacters(in: .whitespaces)
            // Collect until we have a meaningful question (3+ chars — even short commands work)
            if trimmed.count > 3 {
                pendingQuestion = trimmed
                captureNextSentence = false
                questionBuffer = ""
                triggerQuestion(question: pendingQuestion, context: fullContext)
            }
            // Update tail for next chunk regardless
            updateTailWords(from: newWords)
            return
        }

        // ── FIX: Per-word punctuation stripping before trigger detection ─────────────────
        //
        // OLD CODE (buggy):
        //   let cleanedText = newText.trimmingCharacters(in: .punctuationCharacters)
        //   if cleanedText.contains(triggerPhrase) { ... }
        //
        // PROBLEM: `.trimmingCharacters` only strips punctuation from the START and END of
        // the full string. Internal punctuation (e.g. the comma in "Hey, Lumen.") remains.
        // So "hey, lumen".contains("hey lumen") → FALSE. Trigger never fires.
        //
        // The existing sliding-window DID strip per-word with `.trimmingCharacters`, BUT it
        // only operated on newWords from the CURRENT chunk. If the recognizer delivered "Hey,"
        // in one partial result and "Lumen." in the next, the window only saw ["Lumen."] in
        // the second chunk, couldn't form the pair, and missed the trigger.
        //
        // FIX STRATEGY:
        // 1. Strip ALL punctuation characters from EACH word individually (not just trim ends).
        //    Use a CharacterSet approach to remove every punctuation character in the word.
        // 2. Use previousChunkTailWords (last 2 cleaned words from the prior chunk) prepended
        //    to the current chunk's cleaned words when doing the sliding window check.
        //    This catches cross-chunk "Hey, [chunk boundary] Lumen." splits.
        // 3. Also do a fast .contains check on the fully-cleaned joined string as a first pass.

        // Clean each new word by stripping ALL punctuation (not just trimming ends)
        let cleanedNewWords = newWords.map { wordStrippingAllPunctuation($0).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleanedNewWords.isEmpty else {
            updateTailWords(from: newWords)
            return
        }

        // Fast path: joined cleaned words contain the trigger phrase
        let cleanedJoined = cleanedNewWords.joined(separator: " ")
        var triggerFound = cleanedJoined.contains(triggerPhrase)

        // Sliding window path (handles cross-chunk splits via lookback tail)
        if !triggerFound {
            // Prepend last 2 cleaned words from previous chunk to form the search window
            let windowWords = previousChunkTailWords + cleanedNewWords
            for i in 0..<windowWords.count {
                let single = windowWords[i]
                let pair   = i + 1 < windowWords.count ? single + " " + windowWords[i + 1] : single
                if pair == triggerPhrase || single == triggerPhrase {
                    triggerFound = true
                    break
                }
            }
        }

        // Update tail BEFORE handling the trigger (tail is for the next chunk)
        updateTailWords(from: newWords)

        if triggerFound {
            captureNextSentence = true
            triggerDetectedAt = Date()
            questionBuffer = ""
            speakAck()   // immediate audible "On it." while we wait for the question

            // Strip the trigger phrase itself from what we capture next.
            // Work from the cleaned joined string so we don't re-introduce punctuation.
            let afterTrigger = cleanedJoined
                .components(separatedBy: triggerPhrase).last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !afterTrigger.isEmpty {
                questionBuffer = afterTrigger
            }
            DispatchQueue.main.async {
                self.orbState = .triggered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.orbState = .listening
                }
            }
            return
        }
    }

    // MARK: - Helpers

    /// Remove every punctuation character from a word (not just trim ends).
    /// Handles "Hey," → "Hey", "Lumen." → "Lumen", "Hey!" → "Hey",
    /// and edge cases like "hey...lumen" → "heylumen" (uncommon from speech).
    private func wordStrippingAllPunctuation(_ word: String) -> String {
        word.unicodeScalars
            .filter { !CharacterSet.punctuationCharacters.union(.symbols).contains($0) }
            .reduce("") { $0 + String($1) }
    }

    /// Keep the last 2 cleaned words from `words` as the lookback tail for the next chunk.
    private func updateTailWords(from words: [String]) {
        let cleaned = words
            .map { wordStrippingAllPunctuation($0).lowercased() }
            .filter { !$0.isEmpty }
        // Store at most 2 words to detect 2-word trigger phrase across chunk boundaries
        previousChunkTailWords = Array(cleaned.suffix(2))
    }

    // Called if no follow-up detected within 3 seconds of trigger
    func checkTriggerTimeout() {
        guard captureNextSentence, let triggeredAt = triggerDetectedAt else { return }
        if Date().timeIntervalSince(triggeredAt) > 3.0 && questionBuffer.trimmingCharacters(in: .whitespaces).isEmpty {
            captureNextSentence = false
            questionBuffer = ""
            orbState = .idle
        }
    }
    
    // MARK: - Ask Claude
    func triggerQuestion(question: String, context: String) {
        guard !question.isEmpty else { return }
        isProcessing = true
        currentQuestion = question
        orbState = .responding
        
        Task {
            do {
                let answer = try await askClaude(question: question, context: context)
                await MainActor.run {
                    self.currentAnswer = answer
                    self.isShowingResponse = true
                    self.isProcessing = false
                    self.orbState = .idle
                    
                    // Log the insight
                    let insight = LUMENInsight(question: question, answer: answer)
                    self.insights.insert(insight, at: 0)
                    
                    // Speak if voice is enabled
                    if self.isVoiceEnabled {
                        Task { await self.speak(text: answer) }
                    }
                }
            } catch {
                await MainActor.run {
                    self.currentAnswer = "I couldn't process that right now. Please try again."
                    self.isShowingResponse = true
                    self.isProcessing = false
                    self.orbState = .idle
                }
            }
        }
    }
    
    // Manual ask (from post-meeting chat)
    func ask(question: String, context: String) async -> String {
        do {
            return try await askClaude(question: question, context: context)
        } catch {
            return "I couldn't process that request."
        }
    }
    
    private func askClaude(question: String, context: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(claudeKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let systemPrompt = """
        You are LUMEN, an AI meeting assistant. You have access to the live transcript of an ongoing meeting.
        Answer questions concisely and helpfully. Keep responses under 3 sentences for live meeting queries.
        Be direct and professional. If the answer isn't in the transcript, use your general knowledge but mention it.
        """
        
        let userMessage = """
        Meeting transcript so far:
        \(context.prefix(3000))
        
        Question: \(question)
        """
        
        let body: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return (content?["text"] as? String) ?? "I couldn't generate a response."
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
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            // Keep .playAndRecord so the mic stays alive during playback.
            // .duckOthers lowers the recording input so LUMEN's voice is clearly audible.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.play()
        } catch {
            print("LUMEN TTS error: \(error)")
        }
    }

    // AVAudioPlayerDelegate — no-op, just keeps the reference alive
    private lazy var audioPlayerDelegate: AudioPlayerEndDelegate = AudioPlayerEndDelegate()

    // Quick spoken acknowledgement when trigger fires, before answer is ready
    func speakAck() {
        guard isVoiceEnabled else { return }
        Task { await speak(text: "On it.") }
    }
    
    func dismissResponse() {
        isShowingResponse = false
    }
    
    func reset() {
        lastProcessedWordCount = 0
        captureNextSentence = false
        questionBuffer = ""
        pendingQuestion = ""
        previousChunkTailWords = []    // ← also reset the lookback tail on session reset
        orbState = .idle
        isShowingResponse = false
    }
}

// MARK: - Audio Player Delegate (keeps AVAudioPlayer alive through playback)
private class AudioPlayerEndDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Mic session stays active — nothing to restore since we kept .playAndRecord
    }
}
