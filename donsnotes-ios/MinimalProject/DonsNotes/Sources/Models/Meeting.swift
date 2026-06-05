import Foundation
import SwiftUI

enum MeetingStatus: String, Codable {
    case uploading = "UPLOADING"
    case pending = "PENDING"
    case transcribing = "TRANSCRIBING"
    case summarizing = "SUMMARIZING"
    case completed = "COMPLETED"
    case sent = "SENT"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .uploading: return "Uploading..."
        case .pending: return "Pending"
        case .transcribing: return "Transcribing..."
        case .summarizing: return "Summarizing..."
        case .completed: return "Completed"
        case .sent: return "Email Sent"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .completed, .sent: return .green
        case .failed: return .red
        case .uploading, .pending, .transcribing, .summarizing: return .blue
        }
    }
}

struct Meeting: Codable, Identifiable {
    let id: UUID
    let status: MeetingStatus
    let audioUrl: String?
    let transcript: String?
    let summary: String?
    let attendees: [Attendee]
    let organizerName: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case audioUrl = "audio_url"
        case transcript
        case summary
        case attendees
        case organizerName = "organizer_name"
        case createdAt = "created_at"
    }
}
