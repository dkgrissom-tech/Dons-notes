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
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // Current verified entitlement
    @Published var currentTier: SubscriptionTier = .free
    @Published var isOwner: Bool = false

    // StoreKit state
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    @Published var isLoadingProducts: Bool = true

    // Owner bypass (internal demo mode — long-press 3s on footer)
    private let ownerKey = "is_owner_bypass"

    // Transaction listener — must be held for the app lifetime
    private var transactionListenerTask: Task<Void, Error>?

    private init() {
        self.isOwner = UserDefaults.standard.bool(forKey: ownerKey)
        if isOwner { currentTier = .lumenPro }

        // Start listening for transactions before anything else
        transactionListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = LUMENProductID.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            // Sort: pro, lumenPro, lifetime
            self.products = fetched.sorted { a, b in
                let order = LUMENProductID.allCases.map(\.rawValue)
                return (order.firstIndex(of: a.id) ?? 99) < (order.firstIndex(of: b.id) ?? 99)
            }
        } catch {
            // Products unavailable (simulator without StoreKit config, or no internet)
            // App still works — purchases just show an error
            self.products = []
        }
    }

    // MARK: - Purchase
    func purchase(_ productID: LUMENProductID) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil

        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            purchaseError = "Product unavailable. Please try again."
            isPurchasing = false
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateEntitlement(for: transaction)
                await transaction.finish()
            case .userCancelled:
                break  // no error, user just backed out
            case .pending:
                purchaseError = "Purchase pending approval (Ask to Buy)."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    // MARK: - Entitlement Refresh
    // Checks all current entitlements against App Store receipts.
    // Call on app launch and after any purchase.
    func refreshEntitlements() async {
        guard !isOwner else { return }
        var highestTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if !transaction.isUpgraded {
                if let productID = LUMENProductID(rawValue: transaction.productID) {
                    let tier = productID.tier
                    highestTier = max(highestTier, tier)
                }
            }
        }
        self.currentTier = highestTier
    }

    // MARK: - Transaction Listener
    // Handles purchases made outside the app (e.g. family sharing, StoreKit promotions)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? await MainActor.run(body: { [weak self] in
                    try self?.checkVerified(result)
                }) else { continue }
                await MainActor.run { [weak self] in
                    Task { await self?.updateEntitlement(for: transaction) }
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func updateEntitlement(for transaction: Transaction) async {
        if let productID = LUMENProductID(rawValue: transaction.productID) {
            let newTier = productID.tier
            if newTier > currentTier {
                currentTier = newTier
            }
        }
    }

    // MARK: - Owner Bypass (internal demo)
    func setOwnerBypass(_ enabled: Bool) {
        isOwner = enabled
        UserDefaults.standard.set(enabled, forKey: ownerKey)
        currentTier = enabled ? .lumenPro : .free
        if !enabled {
            Task { await refreshEntitlements() }
        }
    }

    // MARK: - Access Guards
    var canUseLumenAI: Bool {
        isOwner || currentTier == .lumenPro || currentTier == .lifetime
    }

    var canTranscribeMore: Bool {
        // Free tier gets 3 meetings/month — always true for now, enforce later with usage tracking
        true
    }

    // MARK: - Formatted price helper
    func price(for productID: LUMENProductID) -> String {
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            // Fallback to static pricing if products not loaded
            return productID.tier.price
        }
        return product.displayPrice
    }
}

// MARK: - SubscriptionTier ordering for entitlement comparison
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
