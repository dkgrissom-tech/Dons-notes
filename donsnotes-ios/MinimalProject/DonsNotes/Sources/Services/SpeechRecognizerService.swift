import Foundation
import Speech
import AVFoundation
import Combine

/// SOLE owner of AVAudioSession and AVAudioEngine for the recording session.
/// From ONE input tap it does three things:
///   1. Feeds SFSpeechAudioBufferRecognitionRequest (live transcription)
///   2. Computes RMS amplitude → publishes `audioLevel` (0.0...1.0) for the orb/waveform
///   3. Writes PCM audio to a .m4a file for upload
///
/// AudioRecorder is a thin stub and must NOT touch the audio session — running a
/// second AVAudioRecorder against the same input was the dual-driver conflict that
/// produced silent taps (audioLevel stuck at 0, dead orb) and broke attendee audio.
final class SpeechRecognizerService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingURL: URL? = nil
    @Published var error: String?

    private var audioFile: AVAudioFile?
    private var recordingOutputURL: URL?

    // Cumulative transcript that survives recognizer restarts (silence/final).
    private var fullTranscript: String = ""

    // MARK: - Public API

 func startListening() {
// Refuse re-entry — if we're already listening, do nothing.
guard !isListening else { return }

fullTranscript = ""
transcript = ""
recordingURL = nil
recordingOutputURL = makeOutputURL()

// 1. Request microphone permission FIRST.
AVAudioApplication.requestRecordPermission { [weak self] micGranted in
guard let self = self else { return }
guard micGranted else {
DispatchQueue.main.async {
self.error = "Microphone access denied. Enable in Settings > Lumen > Microphone."
self.isListening = false
}
return
}

// 2. Then request Speech Recognition permission.
SFSpeechRecognizer.requestAuthorization { status in
DispatchQueue.main.async {
switch status {
case .authorized:
do {
try self.beginRecording()
} catch {
self.error = "Mic error: \(error.localizedDescription)"
self.isListening = false
}
case .denied:
self.error = "Speech recognition denied. Enable in Settings > Lumen."
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
}

    func stopListening() {
        guard isListening else { return }
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        audioLevel = 0
        // Close the file and surface its URL for upload.
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
        // Unconditional teardown — safe no-op when nothing is running yet.
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // ONE session for recognition AND file write.
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

        // Snapshot the cumulative transcript so a restart appends rather than resets.
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
                    // Silence timeout — restart quietly WITHOUT dropping isListening.
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

        // Open the output file in the engine's native input format (AAC/.m4a).
        if let outputURL = recordingOutputURL {
            let fileSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioFile = try? AVAudioFile(forWriting: outputURL, settings: fileSettings)
        }

        // ALWAYS remove before install (done above too) — single tap, three jobs.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // 1. feed recognizer
            self.recognitionRequest?.append(buffer)
            // 2. write to file
            try? self.audioFile?.write(from: buffer)
            // 3. RMS amplitude → audioLevel
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
