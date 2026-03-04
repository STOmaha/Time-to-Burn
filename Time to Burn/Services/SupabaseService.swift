import Foundation
import Supabase
import Auth
import CoreLocation

/// Supabase Service - Handles all backend interactions
@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // MARK: - Properties
    private var client: SupabaseClient!
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    private init() {
        guard SupabaseConfig.isConfigured else {
            print("⚠️ [SupabaseService] Configuration not set. Please update SupabaseConfig.swift with your credentials.")
            return
        }
        
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey
        )
        print("✅ [SupabaseService] Client initialized successfully")

        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Session Management
    
    // Track if session has been checked to prevent duplicate checks
    private var sessionChecked = false

    /// Check for existing authentication session (only logs once)
    func checkSession() async {
        // Prevent redundant session checks during startup
        guard !sessionChecked else { return }
        sessionChecked = true

        print("🔍 [SupabaseService] Checking for existing session...")
        isLoading = true

        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
            print("✅ [SupabaseService] Session found: \(session.user.email ?? "unknown")")
        } catch {
            // Silent - no session is normal for new users
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }
    
    // Track if auth listener is already set up to prevent duplicates
    private var authListenerSetup = false

    /// Listen for authentication state changes (only sets up once)
    func setupAuthListener() {
        // Prevent duplicate listeners
        guard !authListenerSetup else {
            return
        }
        authListenerSetup = true

        print("🔔 [SupabaseService] Setting up auth state listener...")
        Task {
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    // Track previous state to avoid duplicate updates
                    let wasAuthenticated = self.isAuthenticated

                    switch event {
                    case .signedIn:
                        if let session = session {
                            self.currentUser = session.user
                            self.isAuthenticated = true
                            if !wasAuthenticated {
                                print("🔔 [SupabaseService] ✅ SIGNED IN: \(session.user.email ?? "unknown")")
                            }
                        }

                    case .signedOut:
                        self.currentUser = nil
                        self.isAuthenticated = false
                        if wasAuthenticated {
                            print("🔔 [SupabaseService] ℹ️ SIGNED OUT")
                        }

                    case .initialSession:
                        if let session = session {
                            self.currentUser = session.user
                            self.isAuthenticated = true
                            print("🔔 [SupabaseService] 📱 Session restored: \(session.user.email ?? "unknown")")
                        }
                        // Don't log "no session" - that's the normal initial state

                    case .tokenRefreshed, .userUpdated, .passwordRecovery, .mfaChallengeVerified, .userDeleted:
                        // Silent handling for these events - only log if needed for debugging
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Authentication Methods

    /// Sign in with Apple (using ID token from native iOS Apple Sign In)
    /// Note: For native iOS, we don't use a nonce - that's only for web OAuth flows
    func signInWithApple(idToken: String) async throws {
        print("🍎 [SupabaseService] Signing in with Apple (native iOS)...")
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )

            currentUser = session.user
            isAuthenticated = true

            // Create user profile if needed
            await createUserProfileIfNeeded()

            print("✅ [SupabaseService] Apple Sign In successful")
        } catch {
            print("❌ [SupabaseService] Apple Sign In failed: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws {
        print("📧 [SupabaseService] Signing in with email...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            currentUser = session.user
            isAuthenticated = true
            
            print("✅ [SupabaseService] Email sign in successful")
        } catch {
            print("❌ [SupabaseService] Email sign in failed: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String, fullName: String) async throws {
        print("📝 [SupabaseService] Signing up with email...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            
            currentUser = session.user
            isAuthenticated = true
            
            // Create user profile
            await createUserProfileIfNeeded()
            
            print("✅ [SupabaseService] Sign up successful")
        } catch {
            print("❌ [SupabaseService] Sign up failed: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Sign out
    func signOut() async throws {
        print("👋 [SupabaseService] Signing out...")

        do {
            try await client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
            profileVerified = false  // Reset profile verification on sign out
            sessionChecked = false   // Allow session check on next sign in
            print("✅ [SupabaseService] Sign out successful")
        } catch {
            print("❌ [SupabaseService] Sign out failed: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    // MARK: - User Profile Management

    // Track if user profile has been verified to exist
    private var profileVerified = false

    /// Ensure user profile exists before any database operations that reference it
    /// This prevents foreign key constraint violations
    func ensureUserProfileExists() async -> Bool {
        guard let user = currentUser else {
            return false
        }

        // If we've already verified the profile exists in this session, skip the check
        if profileVerified {
            return true
        }

        do {
            // Check if profile exists
            let response: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            if response.isEmpty {
                // Create profile
                let newProfile = NewUserProfile(
                    id: user.id,
                    email: user.email,
                    skinType: "Type II",
                    uvThreshold: 6,
                    notificationEnabled: true,
                    smartIntervalsEnabled: true,
                    locationTrackingEnabled: true
                )

                try await client
                    .from("user_profiles")
                    .insert(newProfile)
                    .execute()

                print("👤 [SupabaseService] User profile created")
            }

            profileVerified = true
            return true
        } catch {
            print("❌ [SupabaseService] Failed to ensure user profile: \(error.localizedDescription)")
            return false
        }
    }

    /// Create user profile if it doesn't exist
    private func createUserProfileIfNeeded() async {
        guard let user = currentUser else {
            print("❌ [SupabaseService] Cannot create profile - no current user")
            return
        }

        print("👤 [SupabaseService] Creating user profile if needed for user: \(user.id)")

        // Verify we have an active session before proceeding
        do {
            let session = try await client.auth.session
            print("👤 [SupabaseService] Active session confirmed for: \(session.user.id)")
        } catch {
            print("❌ [SupabaseService] No active session! Cannot create profile. Error: \(error)")
            return
        }

        do {
            // Check if profile exists - use UUID directly, not string
            print("👤 [SupabaseService] Checking if profile exists...")
            let response: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            print("👤 [SupabaseService] Profile query returned \(response.count) rows")

            if response.isEmpty {
                print("👤 [SupabaseService] No profile found, creating new one...")

                // Create a Codable struct for proper JSON encoding
                // This ensures the UUID is serialized correctly
                let newProfile = NewUserProfile(
                    id: user.id,
                    email: user.email,
                    skinType: "Type II",
                    uvThreshold: 6,
                    notificationEnabled: true,
                    smartIntervalsEnabled: true,
                    locationTrackingEnabled: true
                )

                print("👤 [SupabaseService] Inserting profile for user ID: \(user.id)")

                let insertResponse = try await client
                    .from("user_profiles")
                    .insert(newProfile)
                    .execute()

                print("👤 [SupabaseService] Insert response status: \(insertResponse.status)")
                print("✅ [SupabaseService] User profile created successfully!")
            } else {
                print("ℹ️ [SupabaseService] User profile already exists")
            }
        } catch {
            // Print full error details for debugging
            print("❌ [SupabaseService] Failed to create user profile!")
            print("❌ [SupabaseService] Error type: \(type(of: error))")
            print("❌ [SupabaseService] Error description: \(error.localizedDescription)")
            print("❌ [SupabaseService] Full error: \(error)")

            // Try to extract more details from the error
            if let nsError = error as NSError? {
                print("❌ [SupabaseService] NSError domain: \(nsError.domain)")
                print("❌ [SupabaseService] NSError code: \(nsError.code)")
                print("❌ [SupabaseService] NSError userInfo: \(nsError.userInfo)")
            }
        }
    }
    
    /// Get user profile
    func getUserProfile() async throws -> UserProfile? {
        guard let user = currentUser else { return nil }
        
        print("👤 [SupabaseService] Fetching user profile...")
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value
        
        return response.first
    }
    
    /// Update user profile
    func updateUserProfile(_ profile: UserProfile) async throws {
        guard let user = currentUser else { return }

        print("👤 [SupabaseService] Updating user profile...")

        try await client
            .from("user_profiles")
            .update(profile)
            .eq("id", value: user.id.uuidString)
            .execute()

        print("✅ [SupabaseService] User profile updated")
    }

    // MARK: - Debug & Testing

    /// Debug function to test database connection and auth state
    /// Call this from the app to verify everything is working
    func debugConnectionTest() async {
        print("🔧 [SupabaseService] ========== DEBUG CONNECTION TEST ==========")

        // Test 1: Check if client is initialized
        guard client != nil else {
            print("🔧 [SupabaseService] ❌ TEST 1 FAILED: Client not initialized")
            return
        }
        print("🔧 [SupabaseService] ✅ TEST 1 PASSED: Client initialized")

        // Test 2: Check auth session
        do {
            let session = try await client.auth.session
            print("🔧 [SupabaseService] ✅ TEST 2 PASSED: Active session found")
            print("🔧 [SupabaseService]    User ID: \(session.user.id)")
            print("🔧 [SupabaseService]    Email: \(session.user.email ?? "none")")
            print("🔧 [SupabaseService]    Access Token (first 20 chars): \(String(session.accessToken.prefix(20)))...")
        } catch {
            print("🔧 [SupabaseService] ❌ TEST 2 FAILED: No active session - \(error)")
            return
        }

        // Test 3: Check currentUser
        guard let user = currentUser else {
            print("🔧 [SupabaseService] ❌ TEST 3 FAILED: currentUser is nil")
            return
        }
        print("🔧 [SupabaseService] ✅ TEST 3 PASSED: currentUser is set to \(user.id)")

        // Test 4: Try to query user_profiles
        do {
            let profiles: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            print("🔧 [SupabaseService] ✅ TEST 4 PASSED: Can query user_profiles (found \(profiles.count) profiles)")
        } catch {
            print("🔧 [SupabaseService] ❌ TEST 4 FAILED: Cannot query user_profiles - \(error)")
        }

        // Test 5: Try to insert a profile (if one doesn't exist)
        do {
            // First check if profile exists
            let existingProfiles: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            if existingProfiles.isEmpty {
                print("🔧 [SupabaseService] 📝 TEST 5: Attempting to insert new profile...")
                let newProfile = NewUserProfile(
                    id: user.id,
                    email: user.email,
                    skinType: "Type II",
                    uvThreshold: 6,
                    notificationEnabled: true,
                    smartIntervalsEnabled: true,
                    locationTrackingEnabled: true
                )

                let response = try await client
                    .from("user_profiles")
                    .insert(newProfile)
                    .execute()

                print("🔧 [SupabaseService] ✅ TEST 5 PASSED: Profile inserted! Status: \(response.status)")
            } else {
                print("🔧 [SupabaseService] ℹ️ TEST 5 SKIPPED: Profile already exists")
            }
        } catch {
            print("🔧 [SupabaseService] ❌ TEST 5 FAILED: Cannot insert profile - \(error)")
            // Print more error details
            if let nsError = error as NSError? {
                print("🔧 [SupabaseService]    Domain: \(nsError.domain)")
                print("🔧 [SupabaseService]    Code: \(nsError.code)")
                print("🔧 [SupabaseService]    UserInfo: \(nsError.userInfo)")
            }
        }

        // Test 6: Final check - query profiles again
        do {
            let finalProfiles: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            print("🔧 [SupabaseService] 📊 FINAL STATUS: \(finalProfiles.count) profile(s) for user \(user.id)")
        } catch {
            print("🔧 [SupabaseService] ❌ FINAL CHECK FAILED: \(error)")
        }

        print("🔧 [SupabaseService] ========== DEBUG TEST COMPLETE ==========")
    }

    // MARK: - Device Token Management
    
    /// Register device token for push notifications
    func registerDeviceToken(_ token: String, deviceInfo: DeviceInfo) async throws {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot register device token: user not authenticated")
            return
        }
        
        print("📱 [SupabaseService] Registering device token...")
        
        let device = UserDevice(
            userId: user.id,
            deviceToken: token,
            platform: "ios",
            appVersion: deviceInfo.appVersion,
            deviceModel: deviceInfo.deviceModel,
            osVersion: deviceInfo.osVersion,
            isActive: true
        )
        
        do {
            // Upsert device (insert or update if exists)
            try await client
                .from("user_devices")
                .upsert(device)
                .execute()
            
            print("✅ [SupabaseService] Device token registered successfully")
        } catch {
            print("❌ [SupabaseService] Failed to register device token: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deactivate device token (on logout or uninstall)
    func deactivateDeviceToken(_ token: String) async throws {
        print("📱 [SupabaseService] Deactivating device token...")
        
        try await client
            .from("user_devices")
            .update(["is_active": false])
            .eq("device_token", value: token)
            .execute()
        
        print("✅ [SupabaseService] Device token deactivated")
    }
    
    // MARK: - Location & UV Data Sync
    
    /// Sync location and UV data to Supabase
    func syncLocationData(
        location: CLLocation,
        locationName: String,
        currentUV: Int,
        adjustedUV: Int,
        environmentalFactors: EnvironmentalFactors
    ) async throws {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot sync location: user not authenticated")
            return
        }

        // Ensure user profile exists before inserting location (foreign key constraint)
        guard await ensureUserProfileExists() else {
            print("❌ [SupabaseService] Cannot sync location: user profile not ready")
            return
        }

        print("📍 [SupabaseService] Syncing location data...")
        
        let locationData = UserLocation(
            userId: user.id,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            locationName: locationName,
            currentUvIndex: currentUV,
            adjustedUvIndex: adjustedUV,
            environmentalFactors: environmentalFactors
        )
        
        do {
            // Insert new location record
            try await client
                .from("user_locations")
                .insert(locationData)
                .execute()
            
            print("✅ [SupabaseService] Location data synced successfully")
        } catch {
            print("❌ [SupabaseService] Failed to sync location data: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update user's current location (upsert)
    func updateUserLocation(
        location: CLLocation,
        locationName: String,
        currentUV: Int,
        adjustedUV: Int,
        environmentalFactors: EnvironmentalFactors
    ) async throws {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot update location: user not authenticated")
            return
        }

        // Ensure user profile exists before inserting/updating location (foreign key constraint)
        guard await ensureUserProfileExists() else {
            print("❌ [SupabaseService] Cannot update location: user profile not ready")
            return
        }

        print("📍 [SupabaseService] Updating user location...")
        
        // Get or create the latest location record for this user
        let response: [UserLocation] = try await client
            .from("user_locations")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        if let existingLocation = response.first {
            // Update existing record
            let updated = UserLocation(
                id: existingLocation.id,
                userId: user.id,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: locationName,
                currentUvIndex: currentUV,
                adjustedUvIndex: adjustedUV,
                environmentalFactors: environmentalFactors,
                lastNotifiedAt: existingLocation.lastNotifiedAt
            )
            
            guard let locationId = existingLocation.id else {
                print("⚠️ [SupabaseService] Location ID is missing, cannot update")
                return
            }

            try await client
                .from("user_locations")
                .update(updated)
                .eq("id", value: locationId.uuidString)
                .execute()
        } else {
            // Create new record
            try await syncLocationData(
                location: location,
                locationName: locationName,
                currentUV: currentUV,
                adjustedUV: adjustedUV,
                environmentalFactors: environmentalFactors
            )
        }
        
        print("✅ [SupabaseService] User location updated successfully")
    }
    
    // MARK: - Notification Logs

    /// Log a sent notification
    func logNotification(
        type: String,
        uvIndex: Int,
        threshold: Int,
        location: CLLocation
    ) async throws {
        guard let user = currentUser else { return }

        let log = NotificationLog(
            userId: user.id,
            notificationType: type,
            uvIndex: uvIndex,
            threshold: threshold,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        try await client
            .from("notification_logs")
            .insert(log)
            .execute()
    }

    // MARK: - Subscription Management

    /// Create a new subscription
    func createSubscription(plan: SubscriptionPlan, isMock: Bool = true) async throws {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot create subscription: user not authenticated")
            return
        }

        print("💳 [SupabaseService] Creating subscription for plan: \(plan.displayName)")

        // Calculate expiration date
        let expiresAt = Calendar.current.date(byAdding: .day, value: plan.durationDays, to: Date())

        let subscription = NewUserSubscription(
            userId: user.id,
            planType: plan.rawValue,
            priceCents: plan.priceCents,
            status: "active",
            expiresAt: expiresAt,
            isMock: isMock
        )

        try await client
            .from("user_subscriptions")
            .insert(subscription)
            .execute()

        print("✅ [SupabaseService] Subscription created successfully")
    }

    /// Get current active subscription
    func getCurrentSubscription() async throws -> UserSubscription? {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot get subscription: user not authenticated")
            return nil
        }

        print("💳 [SupabaseService] Fetching subscription for user: \(user.id)")

        let response: [UserSubscription] = try await client
            .from("user_subscriptions")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    /// Cancel a subscription
    func cancelSubscription(subscriptionId: UUID) async throws {
        print("💳 [SupabaseService] Cancelling subscription: \(subscriptionId)")

        try await client
            .from("user_subscriptions")
            .update(["status": "cancelled"])
            .eq("id", value: subscriptionId.uuidString)
            .execute()

        print("✅ [SupabaseService] Subscription cancelled")
    }

    /// Check if user has active subscription
    func hasActiveSubscription() async -> Bool {
        do {
            let subscription = try await getCurrentSubscription()
            return subscription?.isActive ?? false
        } catch {
            print("❌ [SupabaseService] Error checking subscription: \(error)")
            return false
        }
    }

    // MARK: - Developer Tools (Delete All User Data)

    /// Delete all user data from Supabase (for testing fresh install experience)
    func deleteAllUserData() async throws {
        guard let user = currentUser else {
            print("⚠️ [SupabaseService] Cannot delete data: user not authenticated")
            return
        }

        print("🗑️ [SupabaseService] Deleting all data for user: \(user.id)")

        // Delete in order to respect foreign key constraints
        // 1. Delete notification logs
        do {
            try await client
                .from("notification_logs")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .execute()
            print("🗑️ [SupabaseService] ✅ Deleted notification_logs")
        } catch {
            print("🗑️ [SupabaseService] ⚠️ notification_logs delete failed (may not exist): \(error.localizedDescription)")
        }

        // 2. Delete user locations
        do {
            try await client
                .from("user_locations")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .execute()
            print("🗑️ [SupabaseService] ✅ Deleted user_locations")
        } catch {
            print("🗑️ [SupabaseService] ⚠️ user_locations delete failed (may not exist): \(error.localizedDescription)")
        }

        // 3. Delete user devices
        do {
            try await client
                .from("user_devices")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .execute()
            print("🗑️ [SupabaseService] ✅ Deleted user_devices")
        } catch {
            print("🗑️ [SupabaseService] ⚠️ user_devices delete failed (may not exist): \(error.localizedDescription)")
        }

        // 4. Delete subscriptions
        do {
            try await client
                .from("user_subscriptions")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .execute()
            print("🗑️ [SupabaseService] ✅ Deleted user_subscriptions")
        } catch {
            print("🗑️ [SupabaseService] ⚠️ user_subscriptions delete failed (may not exist): \(error.localizedDescription)")
        }

        // 5. Delete user profile
        do {
            try await client
                .from("user_profiles")
                .delete()
                .eq("id", value: user.id.uuidString)
                .execute()
            print("🗑️ [SupabaseService] ✅ Deleted user_profiles")
        } catch {
            print("🗑️ [SupabaseService] ⚠️ user_profiles delete failed (may not exist): \(error.localizedDescription)")
        }

        print("🗑️ [SupabaseService] ✅ All user data deleted from Supabase")
    }
}

// MARK: - Data Models

struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let skinType: String
    let uvThreshold: Int
    let notificationEnabled: Bool
    let smartIntervalsEnabled: Bool
    let locationTrackingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case skinType = "skin_type"
        case uvThreshold = "uv_threshold"
        case notificationEnabled = "notification_enabled"
        case smartIntervalsEnabled = "smart_intervals_enabled"
        case locationTrackingEnabled = "location_tracking_enabled"
    }
}

/// Struct specifically for inserting new user profiles
/// Excludes created_at and updated_at as they have database defaults
struct NewUserProfile: Codable {
    let id: UUID
    let email: String?
    let skinType: String
    let uvThreshold: Int
    let notificationEnabled: Bool
    let smartIntervalsEnabled: Bool
    let locationTrackingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case skinType = "skin_type"
        case uvThreshold = "uv_threshold"
        case notificationEnabled = "notification_enabled"
        case smartIntervalsEnabled = "smart_intervals_enabled"
        case locationTrackingEnabled = "location_tracking_enabled"
    }
}

struct UserDevice: Codable {
    let id: UUID?
    let userId: UUID
    let deviceToken: String
    let platform: String
    let appVersion: String?
    let deviceModel: String?
    let osVersion: String?
    let isActive: Bool
    
    init(
        id: UUID? = nil,
        userId: UUID,
        deviceToken: String,
        platform: String,
        appVersion: String?,
        deviceModel: String?,
        osVersion: String?,
        isActive: Bool
    ) {
        self.id = id
        self.userId = userId
        self.deviceToken = deviceToken
        self.platform = platform
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.isActive = isActive
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceToken = "device_token"
        case platform
        case appVersion = "app_version"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case isActive = "is_active"
    }
}

struct UserLocation: Codable {
    let id: UUID?
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let currentUvIndex: Int?
    let adjustedUvIndex: Int?
    let environmentalFactors: EnvironmentalFactors?
    let lastNotifiedAt: Date?
    
    init(
        id: UUID? = nil,
        userId: UUID,
        latitude: Double,
        longitude: Double,
        locationName: String?,
        currentUvIndex: Int?,
        adjustedUvIndex: Int?,
        environmentalFactors: EnvironmentalFactors?,
        lastNotifiedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.currentUvIndex = currentUvIndex
        self.adjustedUvIndex = adjustedUvIndex
        self.environmentalFactors = environmentalFactors
        self.lastNotifiedAt = lastNotifiedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case locationName = "location_name"
        case currentUvIndex = "current_uv_index"
        case adjustedUvIndex = "adjusted_uv_index"
        case environmentalFactors = "environmental_factors"
        case lastNotifiedAt = "last_notified_at"
    }
}

struct NotificationLog: Codable {
    let id: UUID?
    let userId: UUID
    let notificationType: String
    let uvIndex: Int?
    let threshold: Int?
    let latitude: Double?
    let longitude: Double?
    
    init(
        id: UUID? = nil,
        userId: UUID,
        notificationType: String,
        uvIndex: Int?,
        threshold: Int?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.id = id
        self.userId = userId
        self.notificationType = notificationType
        self.uvIndex = uvIndex
        self.threshold = threshold
        self.latitude = latitude
        self.longitude = longitude
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case notificationType = "notification_type"
        case uvIndex = "uv_index"
        case threshold
        case latitude
        case longitude
    }
}

struct DeviceInfo {
    let appVersion: String?
    let deviceModel: String?
    let osVersion: String?
}

// MARK: - Subscription Models

/// Struct for inserting new subscriptions
struct NewUserSubscription: Codable {
    let userId: UUID
    let planType: String
    let priceCents: Int
    let status: String
    let expiresAt: Date?
    let isMock: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case planType = "plan_type"
        case priceCents = "price_cents"
        case status
        case expiresAt = "expires_at"
        case isMock = "is_mock"
    }
}


