import Foundation
import Speech
import AVFoundation
import Combine

/// Single owner of the AVAudioSession and AVAudioEngine for the entire recording session.
/// Handles both live speech-to-text AND writing PCM audio to a .m4a file.
/// AudioRecorder is no longer used — removing the dual-session conflict was the root fix.
class SpeechRecognizerService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript = ""
    @Published var isListening = false
    @Published var audioLevel: Float = 0
    @Published var error: String?

    // Recording to file
    @Published var recordingURL: URL?
    private var audioFile: AVAudioFile?
    private var recordingOutputURL: URL?

    private var fullTranscript: String = ""
    private var segmentBase: String = ""

    // MARK: - Public API

    func startListening() {
        fullTranscript = ""
        segmentBase = ""
        recordingURL = nil
        recordingOutputURL = makeOutputURL()

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
        audioLevel = 0
        // Close file — surface the URL for upload
        audioFile = nil
        if let url = recordingOutputURL {
            recordingURL = url
        }
    }

    // MARK: - Internal

    private func makeOutputURL() -> URL {
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    private func beginRecording() throws {
        // ── Unconditional teardown — safe no-op if engine isn't running ──────────
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // ── One AVAudioSession for both recognition AND file write ────────────────
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16, *) { request.addsPunctuation = true }
        self.recognitionRequest = request

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let baseAtStart = fullTranscript

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, err in
            guard let self = self else { return }

            if let result = result {
                let segmentText = result.bestTranscription.formattedString
                let combined = baseAtStart.isEmpty ? segmentText : baseAtStart + " " + segmentText
                DispatchQueue.main.async {
                    self.fullTranscript = combined
                    self.transcript = combined
                }
            }

            let isFinal = result?.isFinal ?? false

            if let err = err {
                let nsErr = err as NSError
                if nsErr.code == 1110 {
                    // Silence timeout — restart quietly
                    DispatchQueue.main.async {
                        if self.isListening { try? self.beginRecording() }
                    }
                } else {
                    DispatchQueue.main.async {
                        if self.audioEngine.isRunning { self.audioEngine.stop() }
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        self.isListening = false
                    }
                }
            } else if isFinal {
                DispatchQueue.main.async {
                    if self.isListening { try? self.beginRecording() }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Open AVAudioFile for writing — matches the engine's native input format
        if let outputURL = recordingOutputURL {
            // Convert to .m4a (AAC) settings
            let fileSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioFile = try? AVAudioFile(forWriting: outputURL, settings: fileSettings)
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Feed speech recognizer
            self.recognitionRequest?.append(buffer)
            // Write to file
            try? self.audioFile?.write(from: buffer)
            // RMS amplitude for orb + waveform
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            var sum: Float = 0
            for i in 0..<frameCount { sum += channelData[i] * channelData[i] }
            let rms = sqrt(sum / Float(frameCount))
            let normalized = min(1.0, rms * 8.0)
            DispatchQueue.main.async { self.audioLevel = normalized }
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
