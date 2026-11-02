import Foundation
import StoreKit

@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()
    
    @Published public private(set) var isProUser: Bool = false
    @Published public private(set) var currentTier: SubscriptionTier = .freeTier
    @Published public private(set) var availableProducts: [Product] = []
    
    public static let proMonthlyProductId = "com.scrollsnap.pro.monthly"
    public static let proLifetimeProductId = "com.scrollsnap.pro.lifetime"
    
    private var transactionListener: Task<Void, Never>?
    
    private init() {
        // Strict anti-deadlock rule: zero synchronous singleton calls in init()
        transactionListener = listenForTransactions()
        Task {
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    public func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updatePurchasedStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    public func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                self.isProUser = true
                self.currentTier = .proVip
                return
            }
        }
        self.isProUser = false
        self.currentTier = .freeTier
    }
    
    public func fetchProducts() async {
        do {
            let products = try await Product.products(for: [Self.proMonthlyProductId, Self.proLifetimeProductId])
            self.availableProducts = products
        } catch {
            self.availableProducts = []
        }
    }
    
    public func purchase(product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await updatePurchasedStatus()
                await transaction.finish()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }
    
    public func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
}
