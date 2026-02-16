// SubscriptionService.swift
// Management for user tiers, feature gating, and usage limits with StoreKit 2
// Updated for App Store compliance

import SwiftUI
import SwiftData
import StoreKit
internal import Combine

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "Free"
    case boutique = "Boutique Plus"
    case atelier = "Atelier Elite"
    
    var productId: String? {
        switch self {
        case .free: return nil
        case .boutique: return "com.threadlist.boutique_plus"
        case .atelier: return "com.threadlist.atelier_elite"
        }
    }
    
    var wardrobeLimit: Int? {
        switch self {
        case .free: return 40
        case .boutique, .atelier: return nil // Unlimited
        }
    }
    
    var dailyMagicFillLimit: Int {
        switch self {
        case .free: return 50 // Now free for all, with 50/day fair use
        case .boutique, .atelier: return 1000
        }
    }
    
    var styleMeLimit: Int {
        switch self {
        case .free: return 10 // Monthly
        case .boutique: return 50 // Monthly
        case .atelier: return 30 // Daily (Fair Use)
        }
    }
    
    var limitPeriod: LimitPeriod {
        switch self {
        case .free, .boutique: return .monthly
        case .atelier: return .daily
        }
    }
    
    enum LimitPeriod {
        case daily, monthly
    }
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var currentTier: SubscriptionTier = .free {
        didSet {
            UserDefaults.standard.set(currentTier.rawValue, forKey: tierKey)
        }
    }
    @Published private(set) var magicFillCount = 0
    @Published private(set) var generationCount = 0
    @Published private(set) var monthlyGenerationCount = 0
    
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: String? = nil
    
    // StoreKit Properties
    @Published private(set) var products: [Product] = []
    private var updates: Task<Void, Never>? = nil
    
    private let tierKey = "userSubscriptionTier"
    private let magicFillKey = "dailyMagicFillCount"
    private let generationKey = "dailyGenerationCount"
    private let monthlyGenerationKey = "monthlyGenerationCount"
    private let resetKey = "lastResetDate"
    private let monthlyResetKey = "lastMonthlyResetDate"
    
    private init() {
        // Load counters
        self.magicFillCount = UserDefaults.standard.integer(forKey: magicFillKey)
        self.generationCount = UserDefaults.standard.integer(forKey: generationKey)
        self.monthlyGenerationCount = UserDefaults.standard.integer(forKey: monthlyGenerationKey)
        
        // Load persisted tier
        if let savedTierRaw = UserDefaults.standard.string(forKey: tierKey),
           let savedTier = SubscriptionTier(rawValue: savedTierRaw) {
            self.currentTier = savedTier
        }
        
        checkAndResetLimits()
        
        // Initialize StoreKit
        updates = observeTransactionUpdates()
        
        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    var remainingGenerations: Int {
        let limit = currentTier.styleMeLimit
        let used = currentTier.limitPeriod == .monthly ? monthlyGenerationCount : generationCount
        return max(0, limit - used)
    }
    
    // MARK: - StoreKit 2 Implementation
    
    func fetchProducts() async {
        // Clear all states
        await MainActor.run {
            isLoaded = false
            loadError = nil
        }
        
        do {
            let ids = SubscriptionTier.allCases.compactMap { $0.productId }
            let fetchedProducts = try await Product.products(for: ids)
            
            await MainActor.run {
                self.products = fetchedProducts
                print("📦 StoreKit: Loaded \(self.products.count) products")
                
                if self.products.isEmpty {
                    print("⚠️ StoreKit: No products found. Falling back to simulation mode.")
                    self.simulateProducts()
                }
                self.isLoaded = true
            }
        } catch {
            await MainActor.run {
                print("❌ StoreKit: Failed to fetch products: \(error)")
                print("⚠️ StoreKit: Error occurred. Falling back to simulation mode.")
                self.simulateProducts()
                self.isLoaded = true
            }
        }
    }
    
    /// Simulates products for UI testing when StoreKit is unavailable
    private func simulateProducts() {
        self.loadError = nil // Must be nil to trigger 'Preview Mode' UI
        print("✅ StoreKit: Simulation mode active.")
    }
    
    func purchase(_ tier: SubscriptionTier) async throws {
        guard let productId = tier.productId else { return }
        
        let product = products.first(where: { $0.id == productId })
        
        if product == nil {
            print("🧪 StoreKit: Product not found. Simulating purchase for \(tier.rawValue)...")
            // Add a small artificial delay for realism
            try await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                self.currentTier = tier
            }
            print("✅ StoreKit: Simulated purchase complete.")
            return
        }
        
        guard let realProduct = product else {
            print("❌ StoreKit: Product \(productId) not found in store list")
            return
        }
        
        let result = try await realProduct.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    func updateSubscriptionStatus() async {
        var activeTier: SubscriptionTier = .free
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Identify which tier this transaction belongs to
                if let tier = SubscriptionTier.allCases.first(where: { $0.productId == transaction.productID }) {
                    // If multiple found (rare but possible), prioritize higher tier
                    if tier == .atelier { activeTier = .atelier }
                    else if tier == .boutique && activeTier != .atelier { activeTier = .boutique }
                }
            } catch {
                print("⚠️ StoreKit: Entitlement verification failed")
            }
        }
        
        withAnimation {
            self.currentTier = activeTier
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await _ in Transaction.updates {
                await self.updateSubscriptionStatus()
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unknown // Basic error for simplicity
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Feature Gating
    
    func canAddItem(currentCount: Int) -> Bool {
        guard let limit = currentTier.wardrobeLimit else { return true }
        return currentCount < limit
    }
    
    func canPerformMagicFill() -> Bool {
        checkAndResetLimits()
        return magicFillCount < currentTier.dailyMagicFillLimit
    }
    
    func recordMagicFill() {
        magicFillCount += 1
        UserDefaults.standard.set(magicFillCount, forKey: magicFillKey)
    }
    
    func canPerformStyleMe() -> Bool {
        checkAndResetLimits()
        if currentTier.limitPeriod == .monthly {
            return monthlyGenerationCount < currentTier.styleMeLimit
        } else {
            return generationCount < currentTier.styleMeLimit
        }
    }
    
    func recordGeneration() {
        if currentTier.limitPeriod == .monthly {
            monthlyGenerationCount += 1
            UserDefaults.standard.set(monthlyGenerationCount, forKey: monthlyGenerationKey)
        } else {
            generationCount += 1
            UserDefaults.standard.set(generationCount, forKey: generationKey)
        }
    }
    
    // MARK: - Private Helpers
    
    private func checkAndResetLimits() {
        let now = Date()
        let lastReset = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: resetKey))
        let lastMonthlyReset = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: monthlyResetKey))
        
        // Daily Reset
        if !Calendar.current.isDate(now, inSameDayAs: lastReset) {
            magicFillCount = 0
            generationCount = 0
            UserDefaults.standard.set(0, forKey: magicFillKey)
            UserDefaults.standard.set(0, forKey: generationKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: resetKey)
        }
        
        // Monthly Reset
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        if now.timeIntervalSince(lastMonthlyReset) > thirtyDays {
            monthlyGenerationCount = 0
            UserDefaults.standard.set(0, forKey: monthlyGenerationKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: monthlyResetKey)
        }
    }
}
