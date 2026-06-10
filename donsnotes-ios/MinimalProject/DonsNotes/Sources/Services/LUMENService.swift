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

        let newText = newWords.joined(separator: " ").lowercased()
        guard !newText.isEmpty else { return }

        if captureNextSentence {
            questionBuffer += " " + newText
            let trimmed = questionBuffer.trimmingCharacters(in: .whitespaces)
            // Collect until we have a meaningful sentence (8+ chars of content)
            if trimmed.count > 8 {
                pendingQuestion = trimmed
                captureNextSentence = false
                questionBuffer = ""
                triggerQuestion(question: pendingQuestion, context: fullContext)
            }
            return
        }

        // Detect "hey lumen" in the new words using a sliding 2-word window
        // This catches the phrase even if split across recognition chunks
        let windowWords = newWords.map { $0.lowercased()
            .trimmingCharacters(in: .punctuationCharacters) }
        for i in 0..<windowWords.count {
            let twoWord = i + 1 < windowWords.count
                ? windowWords[i] + " " + windowWords[i + 1]
                : windowWords[i]
            if twoWord == triggerPhrase || windowWords[i] == triggerPhrase {
                captureNextSentence = true
                triggerDetectedAt = Date()
                questionBuffer = ""
                DispatchQueue.main.async {
                    self.orbState = .triggered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.orbState = .listening
                    }
                }
                return
            }
        }
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
            
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("LUMEN TTS error: \(error)")
        }
    }
    
    func dismissResponse() {
        isShowingResponse = false
    }
    
    func reset() {
        lastProcessedWordCount = 0
        captureNextSentence = false
        questionBuffer = ""
        pendingQuestion = ""
        orbState = .idle
        isShowingResponse = false
    }
}
