import Foundation

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case free
    case lifetime
    case monthly
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .free: return "Free"
        case .lifetime: return "Lifetime"
        case .monthly: return "Monthly"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "$0"
        case .lifetime: return "$4.99"
        case .monthly: return "$4.99/mo"
        }
    }
    
    var description: String {
        switch self {
        case .free: return "15 minutes of transcription per month. Great for trying it out."
        case .lifetime: return "3 hours of transcription per month, forever. One-time purchase."
        case .monthly: return "Unlimited transcription, longer summaries, custom templates, and unlimited recipients."
        }
    }
}
