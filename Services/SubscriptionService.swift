// SubscriptionService.swift
// Management for user tiers, feature gating, and usage limits

import SwiftUI
import SwiftData

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "Free"
    case boutique = "Boutique Plus"
    case atelier = "Atelier Elite"
    
    var wardrobeLimit: Int? {
        switch self {
        case .free: return 40
        case .boutique, .atelier: return nil // Unlimited
        }
    }
    
    var dailyMagicFillLimit: Int {
        switch self {
        case .free: return 5
        case .boutique, .atelier: return 1000 // Effectively unlimited
        }
    }
    
    var dailyStyleMeLimit: Int {
        switch self {
        case .free: return 1
        case .boutique, .atelier: return 50
        }
    }
    
    var canImportEmail: Bool {
        self != .free
    }
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @AppStorage("userSubscriptionTier") private var tierRaw = SubscriptionTier.free.rawValue
    
    // Usage tracking (Persisted in AppStorage for simplicity in this version)
    @AppStorage("dailyMagicFillCount") private var magicFillCount = 0
    @AppStorage("dailyGenerationCount") private var generationCount = 0
    @AppStorage("lastResetDate") private var lastResetDate: Double = Date().timeIntervalSince1970
    
    var currentTier: SubscriptionTier {
        SubscriptionTier(rawValue: tierRaw) ?? .free
    }
    
    private init() {
        checkAndResetLimits()
    }
    
    // MARK: - Limit Checks
    
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
    }
    
    func canPerformStyleMe() -> Bool {
        checkAndResetLimits()
        return generationCount < currentTier.dailyStyleMeLimit
    }
    
    func recordGeneration() {
        generationCount += 1
    }
    
    // MARK: - Tier Management
    
    func upgrade(to tier: SubscriptionTier) {
        withAnimation {
            tierRaw = tier.rawValue
        }
    }
    
    // MARK: - Private Helpers
    
    private func checkAndResetLimits() {
        let now = Date()
        let lastReset = Date(timeIntervalSince1970: lastResetDate)
        
        if !Calendar.current.isDate(now, inSameDayAs: lastReset) {
            magicFillCount = 0
            generationCount = 0
            lastResetDate = now.timeIntervalSince1970
        }
    }
}
