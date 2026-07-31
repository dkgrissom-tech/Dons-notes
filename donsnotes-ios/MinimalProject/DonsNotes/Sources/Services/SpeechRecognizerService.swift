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
    /// Shared decorative instance for views that need an orb but no real audio.
    /// Never call startListening() on this instance.
    static let preview = SpeechRecognizerService()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingURL: URL? = nil
    @Published var error: String?

    // Build 100: Proof-of-life timestamp — updated on every audio buffer that
    // actually reaches the engine tap. RecordingView polls isCapturingAudio
    // every second to detect a silently-dead engine (e.g. after a phone call
    // interruption where iOS didn't release the audio session cleanly).
    var lastAudioBufferAt: Date? = nil

    /// True when audio buffers arrived in the last ~3 seconds while listening.
    /// A false value while isListening=true means the engine is dead.
    var isCapturingAudio: Bool {
        guard isListening, let last = lastAudioBufferAt else { return false }
        return Date().timeIntervalSince(last) < 3.0
    }

    private var audioFile: AVAudioFile?
    private var recordingOutputURL: URL?

    // Cumulative transcript that survives recognizer restarts (silence/final).
    private var fullTranscript: String = ""

    // MARK: - Public API

    func startListening(resume: Bool = false) {
        RecordingDiagnostics.shared.log(.engine, "startListening(resume: \(resume)) called; isListening=\(isListening)")
        // Refuse re-entry.
        guard !isListening else {
            RecordingDiagnostics.shared.log(.engine, "startListening GUARD tripped (already listening) — no-op")
            return
        }

        // Build 100: When resuming after an interruption (phone call, Siri, alarm, AirPods),
        // DO NOT clear the transcript — we want to preserve everything captured before the
        // interruption. Only fresh recording starts (resume=false) should wipe state.
        if !resume {
            fullTranscript = ""
            transcript = ""
            recordingURL = nil
        }
        recordingOutputURL = makeOutputURL()

        // Step 1: Microphone permission (iOS 14+ compatible).
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] micGranted in
            guard let self = self else { return }
            guard micGranted else {
                DispatchQueue.main.async {
                    self.error = "Microphone access denied. Enable in Settings > Ora > Microphone."
                    self.isListening = false
                }
                return
            }

            // Step 2: Speech recognition permission.
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
                        self.error = "Speech recognition denied. Enable in Settings > Ora."
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
        RecordingDiagnostics.shared.log(.engine, "stopListening called; isListening=\(isListening)")
        guard isListening else {
            RecordingDiagnostics.shared.log(.engine, "stopListening GUARD tripped (not listening) — no-op")
            return
        }
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        audioLevel = 0
        lastAudioBufferAt = nil  // Build 100: reset proof-of-life on clean stop
        // Close the file and surface its URL for upload.
        audioFile = nil
        if let url = recordingOutputURL {
            recordingURL = url
        }
    }

    /// Build 101: Hard restart for zombie-engine recovery. Used when the audio
    /// engine is dead but isListening got stuck at true — a state neither
    /// startListening (guards on !isListening) nor stopListening (guards on
    /// isListening) can fully recover from on their own.
    ///
    /// Sequence:
    ///   1. Force isListening=false so stopListening() will actually run.
    ///   2. Tear down audio engine, recognition task, tap, and file.
    ///   3. Explicitly deactivate the AVAudioSession to force iOS to release
    ///      the mic hardware (this is what a phone call blocks — Build 100's
    ///      startListening(resume:) never called this).
    ///   4. Wait 500ms for iOS to actually drop the session.
    ///   5. Call startListening(resume:) fresh.
    ///
    /// Preserves the transcript when resume=true (same semantics as
    /// startListening(resume:)).
    func forceRestart(resume: Bool = true, completion: (() -> Void)? = nil) {
        RecordingDiagnostics.shared.log(.force, "forceRestart(resume: \(resume)) STEP 1: cancel task; isListening=\(isListening), engine.isRunning=\(audioEngine.isRunning)")
        // 1. Cancel any in-flight recognition task FIRST so the silence-timeout
        //    error handler can't race in and call beginRecording() while we're
        //    tearing down. Only after that do we bypass the isListening guard.
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        RecordingDiagnostics.shared.log(.force, "STEP 2: force isListening=true then stopListening()")
        isListening = true  // ensure stopListening() below actually runs
        stopListening()

        // 2. Tear down the audio session explicitly. This is critical — a
        //    phone call leaves iOS thinking another process owns the mic, and
        //    only setActive(false) tells iOS to reclaim it for us.
        RecordingDiagnostics.shared.log(.force, "STEP 3: setActive(false, notifyOthersOnDeactivation)")
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            RecordingDiagnostics.shared.log(.session, "setActive(false) succeeded")
        } catch {
            // Non-fatal — iOS may have already released it. Log and continue.
            RecordingDiagnostics.shared.log(.error, "forceRestart: setActive(false) failed: \(error)")
            print("[Ora] forceRestart: setActive(false) failed: \(error)")
        }

        // 3. Wait 500ms for iOS to drop the session, then restart fresh.
        RecordingDiagnostics.shared.log(.force, "STEP 4: sleep 500ms then startListening(resume: \(resume))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            RecordingDiagnostics.shared.log(.force, "STEP 5: teardown wait complete; calling startListening")
            self.startListening(resume: resume)
            completion?()
        }
    }

    // MARK: - Internal

    private func makeOutputURL() -> URL {
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    private func beginRecording() throws {
        RecordingDiagnostics.shared.log(.engine, "beginRecording() enter; engine.isRunning=\(audioEngine.isRunning)")
        // Unconditional teardown — safe no-op when nothing is running yet.
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // ONE session for recognition AND file write.
        let session = AVAudioSession.sharedInstance()
        RecordingDiagnostics.shared.log(.session, "setCategory playAndRecord + setActive(true)")
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
                        RecordingDiagnostics.shared.log(.recognizer, "silence timeout (code 1110); auto-restart beginRecording")
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
        RecordingDiagnostics.shared.log(.engine, "installTap on inputNode; sampleRate=\(inputFormat.sampleRate)")
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Build 103: log the first buffer only so we don't spam the log.
            if self.lastAudioBufferAt == nil {
                RecordingDiagnostics.shared.log(.engine, "FIRST BUFFER received; tap is live")
            }
            // Build 100: proof-of-life timestamp so RecordingView can detect a dead
            // audio engine. Any real audio buffer arriving here updates it.
            self.lastAudioBufferAt = Date()
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
        RecordingDiagnostics.shared.log(.engine, "audioEngine.start() succeeded; isListening=true")
    }
}

private enum SpeechError: LocalizedError {
    case recognizerUnavailable
    var errorDescription: String? { "Speech recognizer is not available right now." }
}
