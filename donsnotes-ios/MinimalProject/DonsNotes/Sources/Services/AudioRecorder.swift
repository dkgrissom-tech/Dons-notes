import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingURL: URL?
    // audioLevel removed — amplitude is now published by SpeechRecognizerService
    // directly from the AVAudioEngine tap (the only live audio path during recording).

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
            audioRecorder?.isMeteringEnabled = false  // metering handled by SpeechRecognizerService
            audioRecorder?.record()

            isRecording = true
            recordingURL = nil   // Clear any previous URL — only set on stop
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
        // Surface URL after stop so upload screen shows correctly
        recordingURL = url
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        meteringTimer?.invalidate()
        meteringTimer = nil
        if flag { recordingURL = recorder.url }
    }
}
