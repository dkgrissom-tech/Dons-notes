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
        case .completed, .sent: return Color(red: 0.2, green: 0.85, blue: 0.6)
        case .failed: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .uploading, .pending, .transcribing, .summarizing: return Color(red: 0.3, green: 0.6, blue: 1.0)
        }
    }
    
    var isProcessing: Bool {
        return self == .uploading || self == .pending || self == .transcribing || self == .summarizing
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
    let actionItems: [String]?
    
    var durationFormatted: String {
        return ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case audioUrl = "audio_url"
        case transcript
        case summary
        case attendees
        case organizerName = "organizer_name"
        case createdAt = "created_at"
        case actionItems = "action_items"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        status = try container.decode(MeetingStatus.self, forKey: .status)
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        attendees = (try? container.decode([Attendee].self, forKey: .attendees)) ?? []
        organizerName = try container.decodeIfPresent(String.self, forKey: .organizerName)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        actionItems = try container.decodeIfPresent([String].self, forKey: .actionItems)
    }
}
