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
    let insights: [LUMENInsight]?
    var title: String? = nil    // Build 90: user-editable meeting title (optional, falls back to date)
    
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
        case insights
        case title
    }
    
    // Memberwise init for use in tests/mocks and local construction
    init(id: UUID, status: MeetingStatus, audioUrl: String?, transcript: String?, summary: String?, attendees: [Attendee], organizerName: String?, createdAt: Date, actionItems: [String]? = nil, insights: [LUMENInsight]? = nil, title: String? = nil) {
        self.id = id
        self.status = status
        self.audioUrl = audioUrl
        self.transcript = transcript
        self.summary = summary
        self.attendees = attendees
        self.organizerName = organizerName
        self.createdAt = createdAt
        self.actionItems = actionItems
        self.insights = insights
        self.title = title
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
        insights = try container.decodeIfPresent([LUMENInsight].self, forKey: .insights)
        title = try container.decodeIfPresent(String.self, forKey: .title)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        try container.encodeIfPresent(transcript, forKey: .transcript)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(attendees, forKey: .attendees)
        try container.encodeIfPresent(organizerName, forKey: .organizerName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(actionItems, forKey: .actionItems)
        try container.encodeIfPresent(insights, forKey: .insights)
        try container.encodeIfPresent(title, forKey: .title)
    }
}
