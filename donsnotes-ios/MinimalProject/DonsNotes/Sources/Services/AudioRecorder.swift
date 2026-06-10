import Foundation

/// Thin stub kept only to satisfy compile references.
/// It must NOT start an AVAudioSession or AVAudioRecorder — running a second audio
/// driver against the same input was the dual-driver conflict that silenced the
/// engine tap. All real recording is owned by SpeechRecognizerService.
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
}
