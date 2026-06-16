import Foundation

// MARK: - ReferralService
// Simple referral code system — no backend required
// Each user gets a unique 6-char code stored in UserDefaults
// When a referred user enters a code at first launch, both get 30 free days of Ora Pro
// "Free days" = stored in UserDefaults as referral_pro_expiry
// SubscriptionService checks this date in canUseLumenAI

final class ReferralService {
    static let shared = ReferralService()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let myCode        = "referral_code"
        static let appliedCode   = "applied_referral_code"
        static let proExpiry     = "referral_pro_expiry"
    }

    // MARK: - Private init (singleton)
    private init() {}

    // MARK: - My Code
    /// Returns this device's unique 6-char referral code, generating it on first access.
    var myCode: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.myCode),
           isValidFormat(existing) {
            return existing
        }
        let code = generateCode()
        UserDefaults.standard.set(code, forKey: Keys.myCode)
        return code
    }

    // MARK: - Apply a Referral Code
    /// Validates format, stores as applied_referral_code, grants 30 days of Ora Pro.
    /// Returns true if the code was valid and applied; false otherwise.
    @discardableResult
    func applyReferralCode(_ code: String) -> Bool {
        let upper = code.uppercased().trimmingCharacters(in: .whitespaces)
        guard isValidFormat(upper) else { return false }
        // Prevent applying own code
        guard upper != myCode else { return false }
        let expiry = Date().addingTimeInterval(30 * 24 * 60 * 60)
        UserDefaults.standard.set(upper, forKey: Keys.appliedCode)
        UserDefaults.standard.set(expiry, forKey: Keys.proExpiry)
        return true
    }

    // MARK: - Referral Bonus Status
    /// True while the referral-granted Pro period is active.
    var hasReferralBonus: Bool {
        guard let expiry = referralProExpiryDate else { return false }
        return expiry > Date()
    }

    /// The stored expiry date, or nil if none has been granted.
    var referralProExpiryDate: Date? {
        UserDefaults.standard.object(forKey: Keys.proExpiry) as? Date
    }

    /// True if the user has already entered a referral code (regardless of whether it's still active).
    var hasAppliedCode: Bool {
        UserDefaults.standard.string(forKey: Keys.appliedCode) != nil
    }

    // MARK: - Helpers
    private func isValidFormat(_ code: String) -> Bool {
        guard code.count == 6 else { return false }
        let allowed = CharacterSet.uppercaseLetters.union(.decimalDigits)
        return code.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func generateCode() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
