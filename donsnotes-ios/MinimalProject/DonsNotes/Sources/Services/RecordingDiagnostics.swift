// Build 103: Lightweight in-memory diagnostic log for recording-lifecycle events.
//
// Design goals:
//  - Zero performance impact on the hot audio path (no file I/O, no locking beyond
//    a simple concurrent queue used only in append)
//  - Ring buffer capped at 500 entries so we don't grow unbounded in a long meeting
//  - Millisecond-precision timestamps for correlating iOS audio events
//  - Categorical prefixes so we can grep the log quickly
//  - Copyable/shareable as plain text
//
// Usage:
//     RecordingDiagnostics.shared.log(.call, "CTCallStateDisconnected fired")
//     RecordingDiagnostics.shared.log(.engine, "isCapturingAudio=\(x), isListening=\(y)")
//     let text = RecordingDiagnostics.shared.exportText()

import Foundation
import Combine

enum DiagnosticCategory: String {
    case call        = "CALL"      // CallKit / CTCallCenter events
    case interrupt   = "INTRPT"    // AVAudioSession interruption began/ended
    case engine      = "ENGINE"    // audio engine start/stop, tap install, buffers
    case session     = "SESSION"   // AVAudioSession setCategory/setActive
    case recognizer  = "SPEECH"    // SFSpeechRecognizer task lifecycle
    case ui          = "UI"        // banner shown, button tapped, view lifecycle
    case retry       = "RETRY"     // retry ladder attempts, auto-resume loop ticks
    case force       = "FORCE"     // forceRestart step-by-step trace
    case error       = "ERROR"     // any error path
    case info        = "INFO"      // generic info
}

final class RecordingDiagnostics: ObservableObject {
    static let shared = RecordingDiagnostics()

    /// Individual log entry.
    struct Entry: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let category: DiagnosticCategory
        let message: String
    }

    // Ring buffer. Cap at 500 so a 2-hour meeting can't grow it unbounded.
    private let maxEntries = 500
    // Serial queue for append; reads copy the array on the main actor.
    private let queue = DispatchQueue(label: "com.ora.diagnostics", qos: .utility)
    // Note: cannot name this `_entries` — that collides with the synthesized
    // storage of the @Published property below.
    private var buffer: [Entry] = []

    /// Published copy for SwiftUI viewers.
    @Published private(set) var entries: [Entry] = []

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        log(.info, "RecordingDiagnostics initialized")
    }

    /// Append a new entry. Safe to call from any thread including audio callbacks.
    func log(_ category: DiagnosticCategory, _ message: String) {
        let entry = Entry(timestamp: Date(), category: category, message: message)
        queue.async {
            self.buffer.append(entry)
            if self.buffer.count > self.maxEntries {
                self.buffer.removeFirst(self.buffer.count - self.maxEntries)
            }
            let snapshot = self.buffer
            DispatchQueue.main.async {
                self.entries = snapshot
            }
        }
    }

    /// Format a single entry for text export / display.
    private func formatEntry(_ e: Entry) -> String {
        let ts = formatter.string(from: e.timestamp)
        return "\(ts) [\(e.category.rawValue)] \(e.message)"
    }

    /// Copyable, shareable plain-text export of the full log.
    /// Includes a header with device info so the log is self-contained.
    func exportText() -> String {
        var out = "=== Ora Recording Diagnostics ===\n"
        out += "Exported: \(formatter.string(from: Date()))\n"
        out += "Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")\n"
        out += "Entries: \(entries.count) (max \(maxEntries))\n"
        out += "\n"
        for e in entries {
            out += formatEntry(e) + "\n"
        }
        return out
    }

    /// Clear the log. Call at the start of a fresh recording so a meeting's
    /// log isn't polluted by the previous one.
    func clear() {
        queue.async {
            self.buffer = []
            DispatchQueue.main.async {
                self.entries = []
            }
        }
    }
}
