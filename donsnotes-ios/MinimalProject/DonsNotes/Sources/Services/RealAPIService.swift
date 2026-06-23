import Foundation

/// Build 86 — Bulletproof, no-backend architecture.
/// Audio, meetings, and contacts all live on-device.
/// AI calls go directly to Groq (chat + Whisper transcription).
class RealAPIService: ObservableObject, APIServiceProtocol {

    // MARK: - Upload (now: local-only + Groq transcription + Groq summary)
    func uploadMeeting(audioURL: URL, attendees: [Attendee], organizerName: String?) async throws -> Meeting {
        // Step 1: create local Meeting in TRANSCRIBING state and persist immediately
        let meetingId = UUID()
        let now = Date()
        let createdMeeting = Meeting(
            id: meetingId,
            status: .transcribing,
            audioUrl: audioURL.absoluteString,   // local file:// URL
            transcript: nil,
            summary: nil,
            attendees: attendees,
            organizerName: organizerName,
            createdAt: now,
            actionItems: nil,
            insights: nil
        )
        var cached = MeetingCacheService.shared.loadMeetings()
        cached.insert(createdMeeting, at: 0)
        MeetingCacheService.shared.saveMeetings(cached)

        // Step 2: transcribe via Groq Whisper
        let transcript: String
        do {
            transcript = try await GroqClient.transcribe(audioURL: audioURL)
        } catch {
            let failed = Self.replacingMeeting(createdMeeting, in: cached, with: { m in
                Meeting(id: m.id, status: .failed, audioUrl: m.audioUrl, transcript: nil, summary: nil,
                        attendees: m.attendees, organizerName: m.organizerName, createdAt: m.createdAt,
                        actionItems: nil, insights: nil)
            })
            MeetingCacheService.shared.saveMeetings(failed)
            throw error
        }

        // Step 3: summarize transcript via Groq chat
        let summary: String
        let actionItems: [String]
        do {
            (summary, actionItems) = try await Self.summarize(transcript: transcript,
                                                              organizerName: organizerName,
                                                              attendees: attendees)
        } catch {
            // Transcript succeeded but summary failed — save what we have
            let partial = Self.replacingMeeting(createdMeeting, in: cached, with: { m in
                Meeting(id: m.id, status: .failed, audioUrl: m.audioUrl, transcript: transcript, summary: nil,
                        attendees: m.attendees, organizerName: m.organizerName, createdAt: m.createdAt,
                        actionItems: nil, insights: nil)
            })
            MeetingCacheService.shared.saveMeetings(partial)
            throw error
        }

        // Step 4: persist completed meeting
        let completed = Meeting(
            id: meetingId,
            status: .completed,
            audioUrl: audioURL.absoluteString,
            transcript: transcript,
            summary: summary,
            attendees: attendees,
            organizerName: organizerName,
            createdAt: now,
            actionItems: actionItems,
            insights: nil
        )
        let final = Self.replacingMeeting(createdMeeting, in: cached, with: { _ in completed })
        MeetingCacheService.shared.saveMeetings(final)
        return completed
    }

    // MARK: - Local-only fetches
    func fetchMeetings() async throws -> [Meeting] {
        return MeetingCacheService.shared.loadMeetings()
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func fetchMeetingDetails(id: UUID) async throws -> Meeting {
        guard let m = MeetingCacheService.shared.loadMeetings().first(where: { $0.id == id }) else {
            throw NSError(domain: "RealAPIService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Meeting not found"])
        }
        return m
    }

    func sendRecapEmail(id: UUID) async throws {
        // Recap email is handled by the mailto: flow in MeetingDetailView.
        // Kept for protocol compatibility but does nothing server-side.
    }

    func fetchContacts() async throws -> [Attendee] {
        return LocalContactsStore.shared.load()
    }

    func saveContact(attendee: Attendee) async throws {
        LocalContactsStore.shared.save(attendee)
    }

    // MARK: - AI (now talks directly to Groq, no backend)
    func askAI(question: String, context: String) async throws -> String {
        let system = """
        You are Ora, a calm, concise meeting assistant. Answer questions about the meeting context the user gives you. Keep answers short — 2-4 sentences unless asked for detail. Never invent facts not in the context.
        """
        let user = """
        Meeting context:
        \(context)

        Question: \(question)
        """

        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: system),
            .init(role: "user", content: user)
        ]

        return try await GroqClient.chat(messages: messages, temperature: 0.3, timeoutSeconds: 20)
    }

    // MARK: - Helpers

    private static func replacingMeeting(_ original: Meeting,
                                         in list: [Meeting],
                                         with transform: (Meeting) -> Meeting) -> [Meeting] {
        list.map { $0.id == original.id ? transform($0) : $0 }
    }

    private static func summarize(transcript: String,
                                  organizerName: String?,
                                  attendees: [Attendee]) async throws -> (summary: String, actionItems: [String]) {
        let attendeeNames = attendees.map { $0.name }.joined(separator: ", ")
        let organizer = organizerName ?? "the organizer"

        let system = """
        You are Ora, a meeting-summary assistant. Given a raw transcript, produce:
        1. A 3-5 sentence summary of what was discussed
        2. A list of concrete action items in the form "PERSON: action by WHEN" (or "PERSON: action" if no when)

        Return ONLY valid JSON with this exact shape:
        {"summary": "...", "action_items": ["...", "..."]}

        No prose before or after the JSON. No markdown fences.
        """
        let user = """
        Organizer: \(organizer)
        Attendees: \(attendeeNames.isEmpty ? "not specified" : attendeeNames)

        Transcript:
        \(transcript)
        """

        let raw = try await GroqClient.chat(
            messages: [.init(role: "system", content: system), .init(role: "user", content: user)],
            temperature: 0.2,
            timeoutSeconds: 30
        )

        // Defensive JSON parse — Groq sometimes wraps in code fences despite instructions
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        struct SummaryJSON: Decodable {
            let summary: String
            let action_items: [String]
        }

        guard let data = cleaned.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(SummaryJSON.self, from: data) else {
            // Fallback: return the raw text as summary, no action items
            return (raw, [])
        }
        return (parsed.summary, parsed.action_items)
    }
}
