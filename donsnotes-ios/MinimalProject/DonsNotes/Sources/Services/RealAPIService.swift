import Foundation

class RealAPIService: APIServiceProtocol {
    private let baseURL = URL(string: "https://api.donsnotes.com/v1")!
    
    func uploadMeeting(audioURL: URL, attendees: [Attendee], organizerName: String?) async throws -> Meeting {
        let uploadURL = baseURL.appendingPathComponent("/meetings/upload")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let attendeeData = try JSONEncoder().encode(attendees)
        let attendeeString = String(data: attendeeData, encoding: .utf8) ?? "[]"
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: audioURL))
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"attendees\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(attendeeString)\r\n".data(using: .utf8)!)
        
        if let organizerName = organizerName {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"organizer_name\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(organizerName)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Meeting.self, from: data)
    }
    
    func fetchMeetings() async throws -> [Meeting] {
        let meetingsURL = baseURL.appendingPathComponent("/meetings")
        let (data, response) = try await URLSession.shared.data(from: meetingsURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meetings: [Meeting] = try decoder.decode([Meeting].self, from: data)
        MeetingCacheService.shared.saveMeetings(meetings)
        return meetings
    }
    
    func fetchMeetingDetails(id: UUID) async throws -> Meeting {
        let meetingURL = baseURL.appendingPathComponent("/meetings/\(id.uuidString.lowercased())")
        let (data, response) = try await URLSession.shared.data(from: meetingURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Meeting.self, from: data)
    }
    
    func sendRecapEmail(id: UUID) async throws {
        let sendURL = baseURL.appendingPathComponent("/meetings/\(id.uuidString.lowercased())/send")
        var request = URLRequest(url: sendURL)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchContacts() async throws -> [Attendee] {
        let contactsURL = baseURL.appendingPathComponent("/contacts")
        let (data, response) = try await URLSession.shared.data(from: contactsURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Attendee].self, from: data)
    }
    
    func saveContact(attendee: Attendee) async throws {
        let contactsURL = baseURL.appendingPathComponent("/contacts")
        var request = URLRequest(url: contactsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(attendee)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw URLError(.badServerResponse)
        }
    }
}
