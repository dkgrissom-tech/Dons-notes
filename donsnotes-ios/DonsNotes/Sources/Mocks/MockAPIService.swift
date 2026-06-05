import Foundation

class MockAPIService: APIServiceProtocol {
    @Published var meetings: [Meeting] = [
        Meeting(id: UUID(), status: .sent, audioUrl: nil, transcript: "This is a mock transcript of a very productive meeting.", summary: "Mock Summary: We discussed building a great app and decided to use SwiftUI.", attendees: [Attendee(email: "don@example.com", name: "Don")], createdAt: Date().addingTimeInterval(-86400)),
        Meeting(id: UUID(), status: .completed, audioUrl: nil, transcript: "Another transcript here.", summary: "Discussed the revenue model: Freemium, Lifetime, and Monthly.", attendees: [Attendee(email: "jane@example.com", name: "Jane")], createdAt: Date().addingTimeInterval(-3600))
    ]
    
    @Published var contacts: [Attendee] = [
        Attendee(email: "don@example.com", name: "Don"),
        Attendee(email: "jane@example.com", name: "Jane")
    ]
    
    func uploadMeeting(audioURL: URL, attendees: [Attendee], organizerName: String?) async throws -> Meeting {
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        let newMeeting = Meeting(id: UUID(), status: .pending, audioUrl: nil, transcript: nil, summary: nil, attendees: attendees, organizerName: organizerName, createdAt: Date())
        meetings.insert(newMeeting, at: 0)
        return newMeeting
    }
    
    func fetchMeetings() async throws -> [Meeting] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return meetings
    }
    
    func fetchMeetingDetails(id: UUID) async throws -> Meeting {
        try await Task.sleep(nanoseconds: 500_000_000)
        if let meeting = meetings.first(where: { $0.id == id }) {
            // Simulate status progression for demonstration if it was pending
            if meeting.status == .pending {
                let updated = Meeting(id: id, status: .transcribing, audioUrl: nil, transcript: nil, summary: nil, attendees: meeting.attendees, createdAt: meeting.createdAt)
                if let index = meetings.firstIndex(where: { $0.id == id }) {
                    meetings[index] = updated
                }
                return updated
            } else if meeting.status == .transcribing {
                let updated = Meeting(id: id, status: .summarizing, audioUrl: nil, transcript: "Mock transcript being generated...", summary: nil, attendees: meeting.attendees, createdAt: meeting.createdAt)
                if let index = meetings.firstIndex(where: { $0.id == id }) {
                    meetings[index] = updated
                }
                return updated
            } else if meeting.status == .summarizing {
                let updated = Meeting(id: id, status: .completed, audioUrl: nil, transcript: "Full mock transcript.", summary: "Final mock summary generated.", attendees: meeting.attendees, createdAt: meeting.createdAt)
                if let index = meetings.firstIndex(where: { $0.id == id }) {
                    meetings[index] = updated
                }
                return updated
            }
            return meeting
        }
        throw URLError(.fileDoesNotExist)
    }
    
    func sendRecapEmail(id: UUID) async throws {
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        if let index = meetings.firstIndex(where: { $0.id == id }) {
            let meeting = meetings[index]
            meetings[index] = Meeting(id: id, status: .sent, audioUrl: meeting.audioUrl, transcript: meeting.transcript, summary: meeting.summary, attendees: meeting.attendees, createdAt: meeting.createdAt)
        }
    }
    
    func fetchContacts() async throws -> [Attendee] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return contacts
    }
    
    func saveContact(attendee: Attendee) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        if !contacts.contains(where: { $0.email == attendee.email }) {
            contacts.append(attendee)
        }
    }
}
