import SwiftUI
import StoreKit

/// Premium subscription paywall view
struct PremiumView: View {
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Products
                    if storeManager.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else if storeManager.products.isEmpty {
                        Text("No products available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        productsSection
                    }

                    // Restore purchases
                    restoreButton

                    // Terms
                    termsSection
                }
                .padding()
            }
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await storeManager.loadProducts()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock Premium")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Get the most out of Time to Burn")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "bell.badge.fill", title: "Unlimited Alerts", description: "Get notified whenever UV conditions change")
            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Detailed Analytics", description: "Track your sun exposure over time")
            FeatureRow(icon: "slider.horizontal.3", title: "Custom Thresholds", description: "Set personalized UV alert levels")
            FeatureRow(icon: "location.fill", title: "Multiple Locations", description: "Monitor UV at multiple saved locations")
            FeatureRow(icon: "xmark.circle.fill", title: "Ad-Free Experience", description: "Enjoy the app without interruptions")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Products
    private var productsSection: some View {
        VStack(spacing: 12) {
            ForEach(storeManager.products, id: \.id) { product in
                ProductButton(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isPurchasing: isPurchasing
                ) {
                    selectedProduct = product
                } onPurchase: {
                    Task {
                        await purchase(product)
                    }
                }
            }
        }
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(storeManager.isLoading)
    }

    // MARK: - Terms
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your App Store account settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://anvilheadstudios.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://anvilheadstudios.com/privacy")!)
            }
            .font(.caption)
        }
        .padding(.top)
    }

    // MARK: - Purchase
    private func purchase(_ product: Product) async {
        isPurchasing = true

        do {
            let success = try await storeManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Product Button
struct ProductButton: View {
    let product: Product
    let isSelected: Bool
    let isPurchasing: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void

    var body: some View {
        Button {
            onSelect()
            onPurchase()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let subscription = product.subscription {
                        Text(subscriptionPeriodText(subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isPurchasing && isSelected {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4)
            )
        }
        .disabled(isPurchasing)
    }

    private func subscriptionPeriodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "Daily" : "Every \(period.value) days"
        case .week:
            return period.value == 1 ? "Weekly" : "Every \(period.value) weeks"
        case .month:
            return period.value == 1 ? "Monthly" : "Every \(period.value) months"
        case .year:
            return period.value == 1 ? "Yearly (Best Value)" : "Every \(period.value) years"
        @unknown default:
            return ""
        }
    }
}

#Preview {
    PremiumView()
}
