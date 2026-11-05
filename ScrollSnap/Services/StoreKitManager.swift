import Foundation
import StoreKit

@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()
    
    private let keyLocalProUnlocked = "ScrollSnap_IsLifetimeProUnlocked"
    
    @Published public private(set) var isProUser: Bool = false
    @Published public private(set) var currentTier: SubscriptionTier = .freeTier
    @Published public private(set) var availableProducts: [Product] = []
    
    /// Product ID for ¥1.00 Permanent Lifetime Unlock (Tier 1 Non-Consumable)
    public static let lifetimeTier1ProductId = "com.scrollsnap.lifetime.tier1"
    
    private var transactionListener: Task<Void, Never>?
    
    private init() {
        if UserDefaults.standard.bool(forKey: keyLocalProUnlocked) {
            self.isProUser = true
            self.currentTier = .lifetimePro
        }
        transactionListener = listenForTransactions()
        Task {
            await updatePurchasedStatus()
            await fetchProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    public func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.updatePurchasedStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    public func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                UserDefaults.standard.set(true, forKey: keyLocalProUnlocked)
                self.isProUser = true
                self.currentTier = .lifetimePro
                return
            }
        }
        if UserDefaults.standard.bool(forKey: keyLocalProUnlocked) {
            self.isProUser = true
            self.currentTier = .lifetimePro
        } else {
            self.isProUser = false
            self.currentTier = .freeTier
        }
    }
    
    public func fetchProducts() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeTier1ProductId])
            self.availableProducts = products
        } catch {
            self.availableProducts = []
        }
    }
    
    public func purchaseLifetimeUnlock() async throws -> Bool {
        if let product = availableProducts.first(where: { $0.id == Self.lifetimeTier1ProductId }) {
            return try await purchase(product: product)
        }
        
        let products = (try? await Product.products(for: [Self.lifetimeTier1ProductId])) ?? []
        if let product = products.first {
            return try await purchase(product: product)
        }
        
        #if DEBUG
        // 开发者/本地调试环境兜底：当未连接 App Store Connect 内购配置时，直接本地解锁 Pro
        unlockLocally()
        return true
        #else
        // 正式发布环境：必须连接苹果 App Store 官方服务器发起真实交易
        return false
        #endif
    }
    
    public func unlockLocally() {
        UserDefaults.standard.set(true, forKey: keyLocalProUnlocked)
        self.isProUser = true
        self.currentTier = .lifetimePro
    }
    
    public func resetToFree() {
        UserDefaults.standard.set(false, forKey: keyLocalProUnlocked)
        self.isProUser = false
        self.currentTier = .freeTier
    }
    
    public func toggleDebugProStatus() {
        if isProUser {
            resetToFree()
        } else {
            unlockLocally()
        }
    }
    
    public func purchase(product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                UserDefaults.standard.set(true, forKey: keyLocalProUnlocked)
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
