// SubscriptionService.swift
// Management for user tiers, feature gating, and usage limits

import SwiftUI
import SwiftData
import Combine

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
    
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var magicFillCount = 0
    @Published private(set) var generationCount = 0
    
    private let tierKey = "userSubscriptionTier"
    private let magicFillKey = "dailyMagicFillCount"
    private let generationKey = "dailyGenerationCount"
    private let resetKey = "lastResetDate"
    
    private init() {
        // Load state
        let savedTier = UserDefaults.standard.string(forKey: tierKey) ?? ""
        self.currentTier = SubscriptionTier(rawValue: savedTier) ?? .free
        
        self.magicFillCount = UserDefaults.standard.integer(forKey: magicFillKey)
        self.generationCount = UserDefaults.standard.integer(forKey: generationKey)
        
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
        UserDefaults.standard.set(magicFillCount, forKey: magicFillKey)
    }
    
    func canPerformStyleMe() -> Bool {
        checkAndResetLimits()
        return generationCount < currentTier.dailyStyleMeLimit
    }
    
    func recordGeneration() {
        generationCount += 1
        UserDefaults.standard.set(generationCount, forKey: generationKey)
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
        
        if !Calendar.current.isDate(now, inSameDayAs: lastReset) {
            magicFillCount = 0
            generationCount = 0
            UserDefaults.standard.set(0, forKey: magicFillKey)
            UserDefaults.standard.set(0, forKey: generationKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: resetKey)
        }
    }
}
