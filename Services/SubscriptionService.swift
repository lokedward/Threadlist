// SubscriptionService.swift
// Management for user tiers, feature gating, and usage limits

import SwiftUI
import SwiftData
internal import Combine

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
        case .free: return 0 // Now disabled for Free users
        case .boutique, .atelier: return 1000
        }
    }
    
    var styleMeLimit: Int {
        switch self {
        case .free: return 3 // Daily
        case .boutique: return 50 // Monthly
        case .atelier: return 30 // Daily (Fair Use Throttle)
        }
    }
    
    var limitPeriod: LimitPeriod {
        switch self {
        case .boutique: return .monthly
        case .free, .atelier: return .daily
        }
    }
    
    enum LimitPeriod {
        case daily, monthly
    }
    
/*
    var canImportEmail: Bool {
        self != .free
    }
*/
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var magicFillCount = 0
    @Published private(set) var generationCount = 0
    @Published private(set) var monthlyGenerationCount = 0
    
    private let tierKey = "userSubscriptionTier"
    private let magicFillKey = "dailyMagicFillCount"
    private let generationKey = "dailyGenerationCount"
    private let monthlyGenerationKey = "monthlyGenerationCount"
    private let resetKey = "lastResetDate"
    private let monthlyResetKey = "lastMonthlyResetDate"
    
    private init() {
        // Load state
        let savedTier = UserDefaults.standard.string(forKey: tierKey) ?? ""
        self.currentTier = SubscriptionTier(rawValue: savedTier) ?? .free
        
        self.magicFillCount = UserDefaults.standard.integer(forKey: magicFillKey)
        self.generationCount = UserDefaults.standard.integer(forKey: generationKey)
        self.monthlyGenerationCount = UserDefaults.standard.integer(forKey: monthlyGenerationKey)
        
        checkAndResetLimits()
    }
    
    var remainingGenerations: Int {
        let limit = currentTier.styleMeLimit
        let used = currentTier.limitPeriod == .monthly ? monthlyGenerationCount : generationCount
        return max(0, limit - used)
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
        UserDefaults.standard.set(magicFillCount, forKey: magicFillKey)
    }
    
    func canPerformStyleMe() -> Bool {
        checkAndResetLimits()
        if currentTier.limitPeriod == .monthly {
            return monthlyGenerationCount < currentTier.styleMeLimit
        } else {
            return generationCount < currentTier.styleMeLimit
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
    
    // MARK: - Tier Management
    
    func upgrade(to tier: SubscriptionTier) {
        withAnimation {
            currentTier = tier
            UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
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
        
        // Monthly Reset (Every 30 days or same day of month)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        if now.timeIntervalSince(lastMonthlyReset) > thirtyDays {
            monthlyGenerationCount = 0
            UserDefaults.standard.set(0, forKey: monthlyGenerationKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: monthlyResetKey)
        }
    }
}
