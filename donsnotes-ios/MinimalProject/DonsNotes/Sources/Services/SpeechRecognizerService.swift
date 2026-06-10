import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognizerService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // fullTranscript: the entire session text, never reset.
    // currentSegment: the running text from the current recognition window.
    // Callers read fullTranscript for trigger detection.
    @Published var transcript = ""         // alias for fullTranscript — views & LUMEN read this
    @Published var isListening = false
    @Published var error: String?

    private var fullTranscript: String = ""   // cumulative across all restart windows
    private var segmentBase: String = ""      // what fullTranscript was when this window started

    // MARK: - Public API

    func startListening() {
        fullTranscript = ""
        segmentBase = ""
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
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Internal

    private func beginRecording() throws {
        // Tear down any running session
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Share the session that AudioRecorder already opened.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        self.recognitionRequest = request

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Snapshot the full transcript before starting this window
        let baseAtStart = fullTranscript

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, err in
            guard let self = self else { return }

            if let result = result {
                // Build rolling full transcript: everything before this window + current segment
                let segmentText = result.bestTranscription.formattedString
                let combined = baseAtStart.isEmpty
                    ? segmentText
                    : baseAtStart + " " + segmentText
                DispatchQueue.main.async {
                    self.fullTranscript = combined
                    self.transcript = combined          // published property views/LUMEN observe
                }
            }

            let isFinal = result?.isFinal ?? false

            if let err = err {
                let nsErr = err as NSError
                if nsErr.code == 1110 {
                    // Silence timeout — restart quietly, preserving fullTranscript
                    DispatchQueue.main.async {
                        if self.isListening { try? self.beginRecording() }
                    }
                } else {
                    DispatchQueue.main.async {
                        if self.audioEngine.isRunning {
                            self.audioEngine.stop()
                            self.audioEngine.inputNode.removeTap(onBus: 0)
                        }
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        self.isListening = false
                    }
                }
            } else if isFinal {
                // Commit the final text of this window into fullTranscript, then restart
                DispatchQueue.main.async {
                    // fullTranscript is already up-to-date from the result handler above
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
