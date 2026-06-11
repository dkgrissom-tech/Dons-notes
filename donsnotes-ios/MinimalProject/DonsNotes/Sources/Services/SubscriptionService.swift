import Foundation
import StoreKit

// MARK: - Product IDs
// These must exactly match the In-App Purchase IDs created in App Store Connect
enum LUMENProductID: String, CaseIterable {
    case pro        = "com.donsnotes.app.pro.monthly"
    case lumenPro   = "com.donsnotes.app.lumenpro.monthly"
    case lifetime   = "com.donsnotes.app.lifetime"

    var tier: SubscriptionTier {
        switch self {
        case .pro:      return .pro
        case .lumenPro: return .lumenPro
        case .lifetime: return .lifetime
        }
    }
}

// MARK: - SubscriptionService (StoreKit 2)
// Not @MainActor — keeps it readable from nonisolated contexts (e.g. LUMENService).
// All @Published mutations happen on the main thread via DispatchQueue.main.async.
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var currentTier: SubscriptionTier = .free
    @Published var isOwner: Bool = false
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    @Published var isLoadingProducts: Bool = true

    private let ownerKey = "is_owner_bypass"
    private var transactionListenerTask: Task<Void, Error>?

    private init() {
        let ownerSaved = UserDefaults.standard.bool(forKey: ownerKey)
        if ownerSaved {
            isOwner = true
            currentTier = .lumenPro
        }
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Access guard (readable from any context — just a computed var on stored props)
    var canUseLumenAI: Bool {
        isOwner || currentTier == .lumenPro || currentTier == .lifetime
    }

    var canTranscribeMore: Bool { true }

    // MARK: - Load Products
    func loadProducts() async {
        DispatchQueue.main.async { self.isLoadingProducts = true }
        do {
            let ids = LUMENProductID.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            let sorted = fetched.sorted { a, b in
                let order = LUMENProductID.allCases.map(\.rawValue)
                return (order.firstIndex(of: a.id) ?? 99) < (order.firstIndex(of: b.id) ?? 99)
            }
            DispatchQueue.main.async {
                self.products = sorted
                self.isLoadingProducts = false
            }
        } catch {
            DispatchQueue.main.async {
                self.products = []
                self.isLoadingProducts = false
            }
        }
    }

    // MARK: - Purchase
    func purchase(_ productID: LUMENProductID) async {
        guard !isPurchasing else { return }
        DispatchQueue.main.async { self.isPurchasing = true; self.purchaseError = nil }

        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            DispatchQueue.main.async {
                self.purchaseError = "Product unavailable. Please try again."
                self.isPurchasing = false
            }
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let newTier = LUMENProductID(rawValue: transaction.productID)?.tier ?? .free
                DispatchQueue.main.async {
                    if newTier > self.currentTier { self.currentTier = newTier }
                    self.isPurchasing = false
                }
                await transaction.finish()
            case .userCancelled:
                DispatchQueue.main.async { self.isPurchasing = false }
            case .pending:
                DispatchQueue.main.async {
                    self.purchaseError = "Purchase pending approval (Ask to Buy)."
                    self.isPurchasing = false
                }
            @unknown default:
                DispatchQueue.main.async { self.isPurchasing = false }
            }
        } catch {
            DispatchQueue.main.async {
                self.purchaseError = "Purchase failed: \(error.localizedDescription)"
                self.isPurchasing = false
            }
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        DispatchQueue.main.async { self.isPurchasing = true; self.purchaseError = nil }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            DispatchQueue.main.async {
                self.purchaseError = "Restore failed: \(error.localizedDescription)"
            }
        }
        DispatchQueue.main.async { self.isPurchasing = false }
    }

    // MARK: - Entitlement Refresh
    func refreshEntitlements() async {
        guard !isOwner else { return }
        var highestTier: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if !transaction.isUpgraded {
                if let pid = LUMENProductID(rawValue: transaction.productID) {
                    highestTier = max(highestTier, pid.tier)
                }
            }
        }
        let tier = highestTier
        DispatchQueue.main.async { self.currentTier = tier }
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                if let pid = LUMENProductID(rawValue: transaction.productID) {
                    let newTier = pid.tier
                    DispatchQueue.main.async {
                        if newTier > self.currentTier { self.currentTier = newTier }
                    }
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - Owner Bypass
    func setOwnerBypass(_ enabled: Bool) {
        isOwner = enabled
        UserDefaults.standard.set(enabled, forKey: ownerKey)
        currentTier = enabled ? .lumenPro : .free
        if !enabled { Task { await refreshEntitlements() } }
    }

    // MARK: - Display Price
    func price(for productID: LUMENProductID) -> String {
        products.first(where: { $0.id == productID.rawValue })?.displayPrice ?? productID.tier.price
    }

    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}

// MARK: - SubscriptionTier Comparable
extension SubscriptionTier: Comparable {
    private var rank: Int {
        switch self {
        case .free:     return 0
        case .pro:      return 1
        case .lumenPro: return 2
        case .lifetime: return 3
        }
    }
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }
}
