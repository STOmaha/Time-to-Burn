import Foundation
import SwiftUI
import CoreLocation

/// Developer tools for testing and debugging
/// WARNING: These tools delete data and should only be used in development
@MainActor
class DeveloperTools: ObservableObject {
    static let shared = DeveloperTools()

    @Published var isResetting = false
    @Published var resetError: Error?
    @Published var resetComplete = false

    // Test status tracking
    @Published var isTesting = false
    @Published var lastTestResult: String = ""
    @Published var lastTestSuccess = false

    private init() {}

    // MARK: - Supabase Test Functions

    /// Test 1: Connection Test - Verifies Supabase client is connected
    func testSupabaseConnection() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Testing Supabase connection...")
        isTesting = true
        defer { isTesting = false }

        // Check if Supabase is configured
        guard SupabaseConfig.isConfigured else {
            let msg = "❌ Supabase not configured - check SupabaseConfig.swift"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }

        // Check if authenticated
        let isAuth = SupabaseService.shared.isAuthenticated
        let hasUser = SupabaseService.shared.currentUser != nil

        if isAuth && hasUser {
            let email = SupabaseService.shared.currentUser?.email ?? "unknown"
            let msg = "✅ Connected! User: \(email)"
            updateTestResult(success: true, message: msg)
            return (true, msg)
        } else {
            let msg = "⚠️ Not authenticated - sign in first"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }
    }

    /// Test 2: User Profile Test - Creates/fetches user profile
    func testUserProfile() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Testing user profile...")
        isTesting = true
        defer { isTesting = false }

        guard SupabaseService.shared.isAuthenticated else {
            let msg = "❌ Not authenticated - sign in first"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }

        do {
            // Try to get existing profile
            if let profile = try await SupabaseService.shared.getUserProfile() {
                let msg = "✅ Profile found! Skin: \(profile.skinType), UV Threshold: \(profile.uvThreshold)"
                updateTestResult(success: true, message: msg)
                return (true, msg)
            } else {
                // Create profile if doesn't exist
                let created = await SupabaseService.shared.ensureUserProfileExists()
                if created {
                    let msg = "✅ Profile created successfully!"
                    updateTestResult(success: true, message: msg)
                    return (true, msg)
                } else {
                    let msg = "❌ Failed to create profile"
                    updateTestResult(success: false, message: msg)
                    return (false, msg)
                }
            }
        } catch {
            let msg = "❌ Profile error: \(error.localizedDescription)"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }
    }

    /// Test 3: Location Sync Test - Syncs current location to Supabase
    func testLocationSync() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Testing location sync...")
        isTesting = true
        defer { isTesting = false }

        guard SupabaseService.shared.isAuthenticated else {
            let msg = "❌ Not authenticated - sign in first"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }

        // Get current location from LocationManager
        guard let location = LocationManager.shared.location else {
            let msg = "❌ No location available - grant location permission"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }

        do {
            // Create test environmental factors with proper initializer
            let factors = EnvironmentalFactors(
                location: location.coordinate,
                altitude: location.altitude
            )

            try await SupabaseService.shared.updateUserLocation(
                location: location,
                locationName: LocationManager.shared.locationName,
                currentUV: 5,
                adjustedUV: 5,
                environmentalFactors: factors
            )

            let msg = "✅ Location synced! Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lon: \(String(format: "%.4f", location.coordinate.longitude))"
            updateTestResult(success: true, message: msg)
            return (true, msg)
        } catch {
            let msg = "❌ Sync error: \(error.localizedDescription)"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }
    }

    /// Test 4: Subscription Test - Creates a mock subscription
    func testSubscription() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Testing subscription...")
        isTesting = true
        defer { isTesting = false }

        guard SupabaseService.shared.isAuthenticated else {
            let msg = "❌ Not authenticated - sign in first"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }

        do {
            // Check for existing subscription
            if let existing = try await SupabaseService.shared.getCurrentSubscription() {
                let msg = "✅ Active subscription found: \(existing.planType), expires: \(existing.expiresAt?.formatted() ?? "never")"
                updateTestResult(success: true, message: msg)
                return (true, msg)
            }

            // Create mock subscription
            try await SupabaseService.shared.createSubscription(plan: .monthly, isMock: true)
            let msg = "✅ Mock subscription created (Monthly plan)"
            updateTestResult(success: true, message: msg)
            return (true, msg)
        } catch {
            let msg = "❌ Subscription error: \(error.localizedDescription)"
            updateTestResult(success: false, message: msg)
            return (false, msg)
        }
    }

    /// Test 5: Full Debug Test - Runs SupabaseService debug test
    func runFullDebugTest() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Running full debug test...")
        isTesting = true
        defer { isTesting = false }

        await SupabaseService.shared.debugConnectionTest()

        let msg = "✅ Debug test complete - check console for details"
        updateTestResult(success: true, message: msg)
        return (true, msg)
    }

    /// Get sync status info
    func getSyncStatusInfo() -> String {
        let syncService = BackgroundSyncService.shared
        var info = "📊 Sync Status:\n"
        info += "• Last sync: \(syncService.getSyncStatus())\n"
        info += "• Next sync: \(syncService.timeUntilNextSync())\n"
        info += "• Is syncing: \(syncService.isSyncing ? "Yes" : "No")"
        return info
    }

    /// Run all tests sequentially
    func runAllTests() async -> (success: Bool, message: String) {
        print("🧪 [DeveloperTools] Running ALL tests...")
        isTesting = true
        defer { isTesting = false }

        var results: [String] = []
        var allPassed = true

        // Test 1: Connection
        let conn = await testSupabaseConnection()
        results.append("1. Connection: \(conn.success ? "✅" : "❌")")
        if !conn.success { allPassed = false }

        // Test 2: Profile
        let profile = await testUserProfile()
        results.append("2. Profile: \(profile.success ? "✅" : "❌")")
        if !profile.success { allPassed = false }

        // Test 3: Location
        let location = await testLocationSync()
        results.append("3. Location: \(location.success ? "✅" : "❌")")
        if !location.success { allPassed = false }

        // Test 4: Subscription
        let sub = await testSubscription()
        results.append("4. Subscription: \(sub.success ? "✅" : "❌")")
        if !sub.success { allPassed = false }

        let summary = results.joined(separator: "\n")
        let finalMsg = allPassed ? "✅ All tests passed!\n\(summary)" : "⚠️ Some tests failed\n\(summary)"
        updateTestResult(success: allPassed, message: finalMsg)
        return (allPassed, finalMsg)
    }

    private func updateTestResult(success: Bool, message: String) {
        lastTestSuccess = success
        lastTestResult = message
        print("🧪 [DeveloperTools] \(message)")
    }

    // MARK: - Full Reset (Simulate Fresh Install)

    /// Completely reset the app to simulate a fresh install
    /// This deletes ALL local data and ALL Supabase data for the current user
    func performFullReset() async -> Bool {
        print("🔧 [DeveloperTools] ========================================")
        print("🔧 [DeveloperTools] STARTING FULL RESET")
        print("🔧 [DeveloperTools] ========================================")

        isResetting = true
        resetError = nil
        resetComplete = false

        defer {
            isResetting = false
        }

        do {
            // Step 1: Delete all Supabase data
            print("🔧 [DeveloperTools] Step 1: Deleting Supabase data...")
            try await SupabaseService.shared.deleteAllUserData()

            // Step 2: Sign out
            print("🔧 [DeveloperTools] Step 2: Signing out...")
            try await AuthenticationManager.shared.signOut()

            // Step 3: Clear all UserDefaults
            print("🔧 [DeveloperTools] Step 3: Clearing UserDefaults...")
            clearAllUserDefaults()

            // Step 4: Reset all managers
            print("🔧 [DeveloperTools] Step 4: Resetting managers...")
            resetAllManagers()

            // Step 5: Clear any cached data
            print("🔧 [DeveloperTools] Step 5: Clearing caches...")
            clearCaches()

            print("🔧 [DeveloperTools] ========================================")
            print("🔧 [DeveloperTools] ✅ FULL RESET COMPLETE")
            print("🔧 [DeveloperTools] ========================================")

            resetComplete = true
            return true

        } catch {
            print("🔧 [DeveloperTools] ❌ Reset failed: \(error.localizedDescription)")
            resetError = error
            return false
        }
    }

    // MARK: - Clear UserDefaults

    private func clearAllUserDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()

        // List of keys to clear
        let keysToRemove = dictionary.keys.filter { key in
            // Clear app-specific keys (keep system keys)
            !key.hasPrefix("Apple") &&
            !key.hasPrefix("NS") &&
            !key.hasPrefix("com.apple")
        }

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
            print("🔧 [DeveloperTools] Removed UserDefault: \(key)")
        }

        defaults.synchronize()
        print("🔧 [DeveloperTools] ✅ UserDefaults cleared (\(keysToRemove.count) keys)")
    }

    // MARK: - Reset Managers

    private func resetAllManagers() {
        // Reset OnboardingManager
        OnboardingManager.shared.resetOnboardingForTesting()
        print("🔧 [DeveloperTools] ✅ OnboardingManager reset")

        // Reset SubscriptionManager
        SubscriptionManager.shared.reset()
        print("🔧 [DeveloperTools] ✅ SubscriptionManager reset")

        // Reset SettingsManager to defaults
        SettingsManager.shared.resetToDefaults()
        print("🔧 [DeveloperTools] ✅ SettingsManager reset")

        // Reset BackgroundSyncService
        BackgroundSyncService.shared.reset()
        print("🔧 [DeveloperTools] ✅ BackgroundSyncService reset")
    }

    // MARK: - Clear Caches

    private func clearCaches() {
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        print("🔧 [DeveloperTools] ✅ URL cache cleared")

        // Clear temporary files
        let tempDirectory = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
            print("🔧 [DeveloperTools] ✅ Temp files cleared (\(files.count) files)")
        }
    }

    // MARK: - Quick Reset (Local Only)

    /// Reset only local data (doesn't touch Supabase)
    func resetLocalDataOnly() {
        print("🔧 [DeveloperTools] Resetting local data only...")

        clearAllUserDefaults()
        resetAllManagers()
        clearCaches()

        print("🔧 [DeveloperTools] ✅ Local data reset complete")
    }
}
