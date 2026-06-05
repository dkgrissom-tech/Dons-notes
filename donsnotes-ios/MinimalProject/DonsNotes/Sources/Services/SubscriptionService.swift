import Foundation

class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var isOwner: Bool = false
    
    private let tierKey = "subscription_tier"
    private let ownerKey = "is_owner_bypass"
    
    private init() {
        if let savedTier = UserDefaults.standard.string(forKey: tierKey),
           let tier = SubscriptionTier(rawValue: savedTier) {
            self.currentTier = tier
        }
        self.isOwner = UserDefaults.standard.bool(forKey: ownerKey)
    }
    
    func upgrade(to tier: SubscriptionTier) {
        self.currentTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
    }
    
    func setOwnerBypass(_ enabled: Bool) {
        self.isOwner = enabled
        UserDefaults.standard.set(enabled, forKey: ownerKey)
        if enabled {
            // Owner gets unlimited (monthly functionality)
            upgrade(to: .monthly)
        }
    }
    
    var canTranscribeMore: Bool {
        if isOwner || currentTier == .monthly { return true }
        // In a real app, we'd check usage against the tier limits
        return true 
    }
}
