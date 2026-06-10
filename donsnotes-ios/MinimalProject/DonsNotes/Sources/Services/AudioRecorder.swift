import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var audioLevel: Float = 0

    private var meteringTimer: Timer?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use .measurement mode so SpeechRecognizerService can share the same
            // session without an AVAudioSession category conflict crash.
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let path = docs.appendingPathComponent(fileName)

            audioRecorder = try AVAudioRecorder(url: path, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingURL = nil   // Clear any previous URL — only set on stop

            startMetering()
        } catch {
            print("AudioRecorder.startRecording error: \(error)")
        }
    }

    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        let url = recorder.url
        recorder.stop()
        isRecording = false
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioLevel = 0
        // Surface URL after stop so upload screen shows correctly
        recordingURL = url
    }

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            DispatchQueue.main.async {
                // Normalize -60…0 dB → 0…1
                self.audioLevel = max(0, min(1, (level + 60) / 60))
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        meteringTimer?.invalidate()
        meteringTimer = nil
        if flag { recordingURL = recorder.url }
    }
}
