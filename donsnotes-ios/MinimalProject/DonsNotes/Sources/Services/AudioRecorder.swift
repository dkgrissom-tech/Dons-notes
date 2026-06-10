import Foundation
import AVFoundation

/// Thin adapter that delegates all recording work to SpeechRecognizerService.
/// Previously AudioRecorder ran its own AVAudioRecorder which conflicted with
/// the AVAudioEngine tap in SpeechRecognizerService — two drivers fighting for
/// the same audio input, causing the engine tap to produce silence.
///
/// Now AudioRecorder holds a reference to the shared SpeechRecognizerService
/// and proxies isRecording / recordingURL so existing callers compile unchanged.
class AudioRecorder: NSObject, ObservableObject {
    // Proxied from SpeechRecognizerService
    @Published var isRecording: Bool = false
    @Published var recordingURL: URL? = nil

    // Injected after init by RecordingView
    weak var speechService: SpeechRecognizerService?

    func startRecording() {
        isRecording = true
        recordingURL = nil
        // Actual recording is started by RecordingView calling speechService.startListening()
    }

    func stopRecording() {
        isRecording = false
        // Actual stop is called by RecordingView calling speechService.stopListening()
        // After stop, SpeechRecognizerService publishes recordingURL — we mirror it
        recordingURL = speechService?.recordingURL
    }
}
