import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognizerService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript = ""
    @Published var isListening = false
    @Published var error: String?

    // MARK: - Public API

    func startListening() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .authorized:
                    do {
                        try self.beginRecording()
                    } catch {
                        self.error = "Mic error: \(error.localizedDescription)"
                        self.isListening = false
                    }
                case .denied:
                    self.error = "Speech recognition denied. Enable in Settings."
                case .restricted:
                    self.error = "Speech recognition restricted on this device."
                case .notDetermined:
                    self.error = "Speech recognition not authorized."
                @unknown default:
                    break
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        // Remove tap before stopping to avoid crash on re-use
        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Internal

    private func beginRecording() throws {
        // Always fully tear down before re-starting
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Share the session that AudioRecorder already opened.
        // Use .measurement mode + duckOthers so both audio paths coexist.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep recognition alive for the whole meeting (iOS 17+)
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        self.recognitionRequest = request

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, err in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async { self.transcript = result.bestTranscription.formattedString }
            }
            // Only tear down on a hard final or non-recoverable error
            let isFinal = result?.isFinal ?? false
            if let err = err {
                let nsErr = err as NSError
                // Code 1110 = no speech — not a crash, just silence; restart quietly
                if nsErr.code == 1110 {
                    DispatchQueue.main.async {
                        if self.isListening { try? self.beginRecording() }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.audioEngine.stop()
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        self.isListening = false
                    }
                }
            } else if isFinal {
                // Auto-restart to keep listening for full meeting
                DispatchQueue.main.async {
                    if self.isListening { try? self.beginRecording() }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }
}

private enum SpeechError: LocalizedError {
    case recognizerUnavailable
    var errorDescription: String? { "Speech recognizer is not available right now." }
}
