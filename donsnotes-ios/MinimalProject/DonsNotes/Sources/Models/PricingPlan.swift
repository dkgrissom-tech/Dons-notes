import Foundation

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case free
    case pro
    case oraPro
    case lifetime

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .free:     return "Free"
        case .pro:      return "Pro"
        case .oraPro: return "Ora Pro"
        case .lifetime: return "Lifetime"
        }
    }

    var price: String {
        switch self {
        case .free:     return "$0"
        case .pro:      return "$12.99/mo"
        case .oraPro: return "$19.99/mo"
        case .lifetime: return "$149"
        }
    }

    var badge: String? {
        switch self {
        case .oraPro: return "POPULAR"
        case .lifetime: return "BEST VALUE"
        default:        return nil
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "3 meetings/month",
                "Basic transcription",
                "7-day history"
            ]
        case .pro:
            return [
                "Unlimited meetings",
                "AI summaries & action items",
                "Audio playback with speed control",
                "Full-text search",
                "Cloud sync",
                "Export (PDF, TXT)"
            ]
        case .oraPro:
            return [
                "Everything in Pro",
                "Ora voice trigger",
                "Live Q&A during meetings",
                "Voice responses (ElevenLabs)",
                "Post-meeting AI chat",
                "LUMEN Insights panel",
                "Calendar integration",
                "Boardroom silent mode"
            ]
        case .lifetime:
            return [
                "All Pro features",
                "One-time payment — no subscription",
                "All future Pro updates included",
                "Priority support",
                "Launch offer pricing"
            ]
        }
    }

    var isHighlighted: Bool {
        self == .oraPro
    }
}
