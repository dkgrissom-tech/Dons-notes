import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingURL: URL?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let fileName = "recording.m4a"
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            recordingURL = path
            
            audioRecorder = try AVAudioRecorder(url: path, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Could not start recording")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
}
