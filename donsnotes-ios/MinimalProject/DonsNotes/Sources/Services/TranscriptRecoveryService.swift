import Foundation

/// Build 100: Manages the transcript_recovery.txt file that RecordingView flushes
/// every 30 seconds during a live meeting. If iOS ever kills the app mid-recording
/// (memory pressure, watchdog, crash), this service surfaces the abandoned transcript
/// on next launch so the user can recover it as a completed meeting instead of
/// losing everything.
///
/// The file format is two lines of ISO-8601 metadata followed by the raw transcript:
///
///     STARTED_AT: 2026-07-31T15:22:04Z
///     LAST_FLUSH: 2026-07-31T15:47:32Z
///     ---
///     <transcript text>
///
/// Older Build 90/91 recovery files that only contain raw transcript (no header)
/// are still detected and handled — the header is optional on read.
enum TranscriptRecoveryService {

    static let filename = "transcript_recovery.txt"
    static let separator = "---"

    /// Metadata + payload recovered from disk.
    struct Recovered {
        let startedAt: Date?
        let lastFlushAt: Date?
        let transcript: String

        var wordCount: Int {
            transcript.split { $0.isWhitespace || $0.isNewline }.count
        }

        var approximateDurationMinutes: Int? {
            guard let start = startedAt, let last = lastFlushAt else { return nil }
            let seconds = last.timeIntervalSince(start)
            guard seconds > 0 else { return nil }
            return Int((seconds / 60).rounded())
        }
    }

    /// Returns the on-disk URL. Never throws — the Documents directory always exists.
    private static var url: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(filename)
    }

    /// True when a non-empty recovery file exists.
    static func hasRecovery() -> Bool {
        guard let url = url,
              FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > 0 else { return false }
        return true
    }

    /// Parse the recovery file. Handles both the Build 100 header format and the
    /// bare-transcript Build 90/91 format. Returns nil if the file is missing or
    /// contains no usable transcript text.
    static func load() -> Recovered? {
        guard let url = url,
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let iso = ISO8601DateFormatter()

        // Fast path: file has the Build 100 header block.
        if let sepRange = raw.range(of: "\n\(separator)\n") {
            let header = raw[..<sepRange.lowerBound]
            let body = String(raw[sepRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }

            var startedAt: Date?
            var lastFlushAt: Date?
            for line in header.split(separator: "\n") {
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "STARTED_AT": startedAt = iso.date(from: value)
                case "LAST_FLUSH": lastFlushAt = iso.date(from: value)
                default: break
                }
            }
            return Recovered(startedAt: startedAt, lastFlushAt: lastFlushAt, transcript: body)
        }

        // Legacy path: raw transcript with no header (Build 90/91 flush format).
        let body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        // Fall back to the file's modification time as a hint for the flush time.
        let modTime = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        return Recovered(startedAt: nil, lastFlushAt: modTime, transcript: body)
    }

    /// Called every 30s from RecordingView during a live meeting. Writes an
    /// atomic replacement so a crash mid-write can never truncate the previous
    /// good snapshot. Silent no-op on errors — this is a best-effort backup.
    static func flush(transcript: String, startedAt: Date) {
        guard !transcript.isEmpty, let url = url else { return }
        let iso = ISO8601DateFormatter()
        let header = """
        STARTED_AT: \(iso.string(from: startedAt))
        LAST_FLUSH: \(iso.string(from: Date()))
        \(separator)

        """
        try? (header + transcript).write(to: url, atomically: true, encoding: .utf8)
    }

    /// Called on clean stop AND after a successful recovery. Idempotent — safe
    /// to call when no file exists.
    static func clear() {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
