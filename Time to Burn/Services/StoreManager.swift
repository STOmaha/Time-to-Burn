import Foundation
import StoreKit

/// Manages In-App Purchases for Time to Burn
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Product IDs
    /// Update these with your actual product IDs from App Store Connect
    enum ProductID: String, CaseIterable {
        case premiumMonthly = "com.anvilheadstudios.timetoburn.premium.monthly"
        case premiumYearly = "com.anvilheadstudios.timetoburn.premium.yearly"

        var displayName: String {
            switch self {
            case .premiumMonthly: return "Premium Monthly"
            case .premiumYearly: return "Premium Yearly"
            }
        }
    }

    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Whether the user has premium access
    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    // MARK: - Private Properties
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check entitlements on init
        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    /// Fetch available products from the App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: Set(productIDs))

            await MainActor.run {
                self.products = storeProducts.sorted { $0.price < $1.price }
                self.isLoading = false
            }

            print("💰 [StoreManager] Loaded \(products.count) products")
            for product in products {
                print("  - \(product.displayName): \(product.displayPrice)")
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("💰 [StoreManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)

                // Update purchased products
                await MainActor.run {
                    self.purchasedProductIDs.insert(transaction.productID)
                    self.isLoading = false
                    self.errorMessage = nil  // Clear any previous errors on success
                }

                // Always finish a transaction
                await transaction.finish()

                print("💰 [StoreManager] Successfully purchased: \(product.displayName)")
                return true

            case .userCancelled:
                await MainActor.run {
                    self.isLoading = false
                }
                print("💰 [StoreManager] User cancelled purchase")
                return false

            case .pending:
                await MainActor.run {
                    self.isLoading = false
                }
                print("💰 [StoreManager] Purchase pending (e.g., Ask to Buy)")
                return false

            @unknown default:
                await MainActor.run {
                    self.isLoading = false
                }
                return false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("💰 [StoreManager] Purchase failed: \(error)")
            throw error
        }
    }

    // MARK: - Restore Purchases
    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkEntitlements()

            await MainActor.run {
                self.isLoading = false
                self.errorMessage = nil  // Clear any previous errors on success
            }

            print("💰 [StoreManager] Purchases restored successfully")

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("💰 [StoreManager] Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Check Entitlements
    /// Check current entitlements (what the user has purchased)
    func checkEntitlements() async {
        var purchasedIDs: Set<String> = []

        // Check for current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("💰 [StoreManager] Failed to verify transaction: \(error)")
            }
        }

        await MainActor.run {
            self.purchasedProductIDs = purchasedIDs
        }

        print("💰 [StoreManager] Current entitlements: \(purchasedIDs)")
    }

    // MARK: - Transaction Listener
    /// Listen for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    await MainActor.run {
                        if transaction.revocationDate == nil {
                            self.purchasedProductIDs.insert(transaction.productID)
                        } else {
                            self.purchasedProductIDs.remove(transaction.productID)
                        }
                    }

                    await transaction.finish()
                    print("💰 [StoreManager] Transaction updated: \(transaction.productID)")

                } catch {
                    print("💰 [StoreManager] Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification Helper
    /// Verify that a transaction is legitimate
    /// Note: This is nonisolated because it doesn't access any actor state
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Product Helpers
    /// Get a product by its ID
    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Get the monthly subscription product
    var monthlyProduct: Product? {
        product(for: .premiumMonthly)
    }

    /// Get the yearly subscription product
    var yearlyProduct: Product? {
        product(for: .premiumYearly)
    }
}

// MARK: - Premium Features
extension StoreManager {
    /// Features available only to premium users
    enum PremiumFeature {
        case unlimitedAlerts
        case detailedAnalytics
        case customThresholds
        case multipleLocations
        case adFree
    }

    /// Check if a specific premium feature is available
    func hasAccess(to feature: PremiumFeature) -> Bool {
        isPremium
    }

    /// Check if premium feature is available (static helper for use in views)
    @MainActor
    static func isPremiumFeatureAvailable(_ feature: PremiumFeature) -> Bool {
        shared.isPremium
    }
}
