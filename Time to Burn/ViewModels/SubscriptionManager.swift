import Foundation
import SwiftUI
import Combine

// MARK: - Subscription Plan Model

enum SubscriptionPlan: String, Codable, CaseIterable {
    case monthly = "monthly"
    case annualFamily = "annual_family"

    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .annualFamily:
            return "Annual + Family"
        }
    }

    var price: Decimal {
        switch self {
        case .monthly:
            return 4.99
        case .annualFamily:
            return 49.99
        }
    }

    var priceString: String {
        switch self {
        case .monthly:
            return "$4.99/month"
        case .annualFamily:
            return "$49.99/year"
        }
    }

    var priceCents: Int {
        switch self {
        case .monthly:
            return 499
        case .annualFamily:
            return 4999
        }
    }

    var description: String {
        switch self {
        case .monthly:
            return "Billed monthly, cancel anytime"
        case .annualFamily:
            return "Share with up to 5 family members"
        }
    }

    var savings: String? {
        switch self {
        case .monthly:
            return nil
        case .annualFamily:
            return "Save 17%"
        }
    }

    var icon: String {
        switch self {
        case .monthly:
            return "person.fill"
        case .annualFamily:
            return "person.3.fill"
        }
    }

    var durationDays: Int {
        switch self {
        case .monthly:
            return 30
        case .annualFamily:
            return 365
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable {
    case active = "active"
    case cancelled = "cancelled"
    case expired = "expired"
    case none = "none"
}

// MARK: - User Subscription Model

struct UserSubscription: Codable {
    let id: UUID?
    let userId: UUID
    let planType: String
    let priceCents: Int
    let status: String
    let startedAt: Date?
    let expiresAt: Date?
    let isMock: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planType = "plan_type"
        case priceCents = "price_cents"
        case status
        case startedAt = "started_at"
        case expiresAt = "expires_at"
        case isMock = "is_mock"
    }

    var plan: SubscriptionPlan? {
        SubscriptionPlan(rawValue: planType)
    }

    var subscriptionStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: status) ?? .none
    }

    var isActive: Bool {
        subscriptionStatus == .active && (expiresAt ?? Date.distantFuture) > Date()
    }
}

// MARK: - Subscription Manager (ViewModel)

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var currentSubscription: UserSubscription?
    @Published var selectedPlan: SubscriptionPlan?
    @Published var isPurchasing = false
    @Published var purchaseError: Error?
    @Published var showPurchaseSuccess = false

    // MARK: - Computed Properties

    var isSubscribed: Bool {
        currentSubscription?.isActive ?? false
    }

    var currentPlan: SubscriptionPlan? {
        currentSubscription?.plan
    }

    var subscriptionStatus: SubscriptionStatus {
        currentSubscription?.subscriptionStatus ?? .none
    }

    // MARK: - Initialization

    private init() {
        print("💳 [SubscriptionManager] Initialized")
    }

    // MARK: - Purchase Methods

    /// Purchase a subscription (mock implementation for testing)
    func purchase(plan: SubscriptionPlan) async -> Bool {
        print("💳 [SubscriptionManager] Starting purchase for: \(plan.displayName)")

        isPurchasing = true
        purchaseError = nil
        selectedPlan = plan

        defer {
            isPurchasing = false
        }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        do {
            // Create mock subscription in Supabase
            try await SupabaseService.shared.createSubscription(plan: plan, isMock: true)

            // Fetch the updated subscription
            await fetchCurrentSubscription()

            showPurchaseSuccess = true
            print("💳 [SubscriptionManager] ✅ Purchase successful!")

            // Auto-hide success message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showPurchaseSuccess = false
            }

            return true
        } catch {
            print("💳 [SubscriptionManager] ❌ Purchase failed: \(error.localizedDescription)")
            purchaseError = error
            return false
        }
    }

    /// Fetch current subscription from Supabase
    func fetchCurrentSubscription() async {
        print("💳 [SubscriptionManager] Fetching current subscription...")

        do {
            currentSubscription = try await SupabaseService.shared.getCurrentSubscription()

            if let sub = currentSubscription {
                print("💳 [SubscriptionManager] ✅ Found subscription: \(sub.planType), status: \(sub.status)")
            } else {
                print("💳 [SubscriptionManager] ℹ️ No active subscription found")
            }
        } catch {
            print("💳 [SubscriptionManager] ❌ Failed to fetch subscription: \(error.localizedDescription)")
        }
    }

    /// Cancel subscription (mock implementation)
    func cancelSubscription() async -> Bool {
        print("💳 [SubscriptionManager] Cancelling subscription...")

        guard let subscription = currentSubscription else {
            print("💳 [SubscriptionManager] ⚠️ No subscription to cancel")
            return false
        }

        do {
            try await SupabaseService.shared.cancelSubscription(subscriptionId: subscription.id!)
            await fetchCurrentSubscription()
            print("💳 [SubscriptionManager] ✅ Subscription cancelled")
            return true
        } catch {
            print("💳 [SubscriptionManager] ❌ Failed to cancel: \(error.localizedDescription)")
            return false
        }
    }

    /// Restore purchases (mock - just fetches current subscription)
    func restorePurchases() async -> Bool {
        print("💳 [SubscriptionManager] Restoring purchases...")

        isPurchasing = true
        defer { isPurchasing = false }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await fetchCurrentSubscription()

        return isSubscribed
    }

    /// Reset for testing
    func reset() {
        currentSubscription = nil
        selectedPlan = nil
        isPurchasing = false
        purchaseError = nil
        showPurchaseSuccess = false
    }
}
