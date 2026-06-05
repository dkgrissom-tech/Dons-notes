import Foundation
import Speech
import Combine

class SpeechRecognizerService: ObservableObject {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var transcript = ""
    @Published var isListening = false
    @Published var error: String?
    
    func startListening() {
        transcript = ""
        error = nil
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.beginRecording()
                case .denied:
                    self?.error = "Speech recognition authorization denied"
                case .restricted:
                    self?.error = "Speech recognition restricted on this device"
                case .notDetermined:
                    self?.error = "Speech recognition not determined"
                @unknown default:
                    self?.error = "Unknown speech recognition authorization status"
                }
            }
        }
    }
    
    private func beginRecording() {
        do {
            try startRecording()
            isListening = true
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            isListening = false
        }
    }
    
    func stopListening() {
        if isListening {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isListening = false
        }
    }
    
    private func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isListening = false
                
                if let error = error {
                    self.error = "Recognition error: \(error.localizedDescription)"
                } else if self.transcript.isEmpty {
                    self.error = "No speech detected. Please try again."
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
}
