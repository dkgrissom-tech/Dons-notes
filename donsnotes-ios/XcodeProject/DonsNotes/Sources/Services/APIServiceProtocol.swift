import Foundation

protocol APIServiceProtocol: ObservableObject {
    func uploadMeeting(audioURL: URL, attendees: [Attendee], organizerName: String?) async throws -> Meeting
    func fetchMeetings() async throws -> [Meeting]
    func fetchMeetingDetails(id: UUID) async throws -> Meeting
    func sendRecapEmail(id: UUID) async throws
    func fetchContacts() async throws -> [Attendee]
    func saveContact(attendee: Attendee) async throws
}
