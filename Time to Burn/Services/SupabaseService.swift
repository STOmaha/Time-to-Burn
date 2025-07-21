import Foundation
import CoreLocation

// MARK: - Mock Supabase Types (temporary until package is properly configured)
struct MockSupabaseUser {
    let id: UUID
    let email: String?
    let createdAt: Date
    let userMetadata: [String: Any]?
}

struct MockAuthResponse {
    let user: MockSupabaseUser?
}

struct MockAuthCredentials {
    let provider: MockAuthProvider
    let idToken: String
}

enum MockAuthProvider {
    case apple
    case google
}

struct MockSupabaseClient {
    var auth: MockAuthService
    var database: MockDatabaseService
    
    init(supabaseURL: URL, supabaseKey: String) {
        self.auth = MockAuthService()
        self.database = MockDatabaseService()
    }
}

struct MockDatabaseService {
    func from(_ table: String) -> MockQueryBuilder {
        return MockQueryBuilder()
    }
}

struct MockQueryBuilder {
    func insert(_ values: [String: Any]) async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
    
    func select(_ columns: String...) async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
    
    func update(_ values: [String: Any]) async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
    
    func delete() async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
    
    func eq(_ column: String, value: Any) -> MockQueryBuilder {
        return self
    }
    
    func single() async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
    
    func single() -> MockQueryBuilder {
        return self
    }
    
    func upsert(_ values: [String: Any]) -> MockQueryBuilder {
        return self
    }
    
    func execute() async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
}

struct MockQueryResponse {
    var data: [String: Any]? {
        return [:]
    }
    
    func execute() async throws -> MockQueryResponse {
        return self
    }
    
    func eq(_ column: String, value: String) -> MockQueryResponse {
        return self
    }
    
    func eq(_ column: String, value: Bool) -> MockQueryResponse {
        return self
    }
    
    func limit(_ count: Int) -> MockQueryResponse {
        return self
    }
    
    func order(_ column: String, ascending: Bool) -> MockQueryResponse {
        return self
    }
    
    func single() -> MockQueryResponse {
        return self
    }
    
    func upsert(_ values: [String: Any]) async throws -> MockQueryResponse {
        return MockQueryResponse()
    }
}

struct MockAuthService {
    var session: MockSupabaseUser? {
        return nil
    }
    
    func signUp(email: String, password: String) async throws -> MockAuthResponse {
        let mockUser = MockSupabaseUser(
            id: UUID(),
            email: email,
            createdAt: Date(),
            userMetadata: ["full_name": "Mock User"]
        )
        return MockAuthResponse(user: mockUser)
    }
    
    func signIn(email: String, password: String) async throws -> MockAuthResponse {
        let mockUser = MockSupabaseUser(
            id: UUID(),
            email: email,
            createdAt: Date(),
            userMetadata: ["full_name": "Mock User"]
        )
        return MockAuthResponse(user: mockUser)
    }
    
    func signOut() async throws {
        // Mock implementation - always succeeds
    }
    
    func resetPasswordForEmail(_ email: String) async throws {
        // Mock implementation - always succeeds
    }
    
    func signInWithIdToken(credentials: MockAuthCredentials) async throws -> MockAuthResponse {
        // Mock implementation - always succeeds
        return MockAuthResponse(user: MockSupabaseUser(
            id: UUID(),
            email: "mock@example.com",
            createdAt: Date(),
            userMetadata: nil
        ))
    }
}

// MARK: - Supabase Service
@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // MARK: - Properties
    private let client: MockSupabaseClient
    
    // Published properties for UI updates
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - User Type Conversion
    
    private func convertSupabaseUser(_ supabaseUser: MockSupabaseUser?) -> User? {
        guard let supabaseUser = supabaseUser else { return nil }
        return User(
            id: supabaseUser.id,
            email: supabaseUser.email,
            createdAt: supabaseUser.createdAt,
            userMetadata: supabaseUser.userMetadata
        )
    }
    
    // MARK: - Initialization
    private init() {
        // TODO: Replace with your actual Supabase credentials
        let supabaseURL = URL(string: "https://svkrlwzwnirhgbyardze.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2a3Jsd3p3bmlyaGdieWFyZHplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Mjk1OTcsImV4cCI6MjA2ODAwNTU5N30.qKyu4nuFwtU-Vsa_0JIeiQrbfMgLFF2R6EwMwLnzsc4"
        
        self.client = MockSupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        print("🌐 [SupabaseService] 🚀 Initialized with URL: \(supabaseURL)")
        
        // Check if user is already authenticated
        Task {
            await checkAuthenticationStatus()
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Check if user is currently authenticated
    private func checkAuthenticationStatus() async {
        let session = client.auth.session
        await MainActor.run {
            self.isAuthenticated = session != nil
            self.currentUser = self.convertSupabaseUser(session)
            print("🌐 [SupabaseService] ✅ Authentication status: \(self.isAuthenticated ? "Authenticated" : "Not authenticated")")
        }
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String, name: String) async throws {
        isLoading = true
        error = nil
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                self.isLoading = false
                print("🌐 [SupabaseService] ✅ Sign up successful")
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("🌐 [SupabaseService] ❌ Sign up failed: \(error)")
            }
            throw error
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                self.isLoading = false
                print("🌐 [SupabaseService] ✅ Sign in successful")
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("🌐 [SupabaseService] ❌ Sign in failed: \(error)")
            }
            throw error
        }
    }
    
    /// Sign out
    func signOut() async throws {
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                print("🌐 [SupabaseService] ✅ Sign out successful")
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("🌐 [SupabaseService] ❌ Sign out failed: \(error)")
            }
            throw error
        }
    }
    
    /// Reset password
    func resetPassword(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email)
            print("🌐 [SupabaseService] ✅ Password reset email sent")
        } catch {
            await MainActor.run {
                self.error = error
                print("🌐 [SupabaseService] ❌ Password reset failed: \(error)")
            }
            throw error
        }
    }
    
    /// Sign in with Apple
    func signInWithApple(identityToken: String) async throws {
        print("🌐 [SupabaseService] 🍎 Signing in with Apple")
        
        do {
            let authResponse = try await client.auth.signInWithIdToken(
                credentials: MockAuthCredentials(
                    provider: .apple,
                    idToken: identityToken
                )
            )
            
            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                print("🌐 [SupabaseService] ✅ Apple sign in successful")
            }
        } catch {
            print("🌐 [SupabaseService] ❌ Apple sign in failed: \(error)")
            throw error
        }
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws {
        print("🌐 [SupabaseService] 🔍 Signing in with Google")
        
        do {
            // For now, this is a mock implementation
            // In a real app, you would integrate with Google Sign-In SDK
            let authResponse = try await client.auth.signInWithIdToken(
                credentials: MockAuthCredentials(
                    provider: .google,
                    idToken: "mock_google_token"
                )
            )
            
            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                print("🌐 [SupabaseService] ✅ Google sign in successful")
            }
        } catch {
            print("🌐 [SupabaseService] ❌ Google sign in failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Database Operations
    
    /// Create user profile
    func createUserProfile(email: String, name: String) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let profileData: [String: Any] = [
            "user_id": userId.uuidString,
            "email": email,
            "full_name": name,
            "created_at": Date().timeIntervalSince1970
        ]
        
        do {
            let response = try await client.database
                .from("user_profiles")
                .insert(profileData)
                .execute()
            
            print("🌐 [SupabaseService] ✅ User profile created")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to create user profile: \(error)")
            throw error
        }
    }
    
    /// Save user location
    func saveUserLocation(latitude: Double, longitude: Double) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let locationData: [String: Any] = [
            "user_id": userId.uuidString,
            "latitude": latitude,
            "longitude": longitude,
            "recorded_at": Date().timeIntervalSince1970
        ]
        
        do {
            _ = try await client.database
                .from("user_locations")
                .insert(locationData)
                .execute()
            
            print("🌐 [SupabaseService] ✅ User location saved")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save user location: \(error)")
            throw error
        }
    }
    
    /// Save UV monitoring data
    func saveUVData(uvIndex: Double, latitude: Double, longitude: Double, environmentalFactors: EnvironmentalFactors) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let uvData: [String: Any] = [
            "user_id": userId.uuidString,
            "uv_index": uvIndex,
            "latitude": latitude,
            "longitude": longitude,
            "recorded_at": Date().timeIntervalSince1970,
            "altitude": environmentalFactors.altitude,
            "environmental_factors": environmentalFactors.toDictionary()
        ]
        
        do {
            _ = try await client.database
                .from("uv_monitoring_data")
                .insert(uvData)
                .execute()
            
            print("🌐 [SupabaseService] ✅ UV data saved")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save UV data: \(error)")
            throw error
        }
    }
    
    /// Save user preferences
    func saveUserPreferences(preferences: [String: Any]) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        var preferenceData = preferences
        preferenceData["user_id"] = userId.uuidString
        preferenceData["updated_at"] = Date().timeIntervalSince1970
        
        do {
            _ = try await client.database
                .from("user_preferences")
                .upsert(preferenceData)
                .execute()
            
            print("🌐 [SupabaseService] ✅ User preferences saved")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save user preferences: \(error)")
            throw error
        }
    }
    
    /// Get user preferences
    func getUserPreferences() async throws -> [String: Any]? {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            let response = try await client.database
                .from("user_preferences")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            return response.data as? [String: Any]
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get user preferences: \(error)")
            throw error
        }
    }
    
    /// Get user profile
    func getUserProfile() async throws -> [String: Any]? {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            let response = try await client.database
                .from("user_profiles")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            return response.data as? [String: Any]
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get user profile: \(error)")
            throw error
        }
    }
    
    /// Create default user preferences
    func createDefaultUserPreferences() async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let defaultPreferences: [String: Any] = [
            "user_id": userId.uuidString,
            "notifications_enabled": true,
            "uv_alert_threshold": 3,
            "location_sharing": false,
            "created_at": Date().timeIntervalSince1970
        ]
        
        do {
            _ = try await client.database
                .from("user_preferences")
                .insert(defaultPreferences)
                .execute()
            
            print("🌐 [SupabaseService] ✅ Default user preferences created")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to create default user preferences: \(error)")
            throw error
        }
    }
    
    /// Get UV history for user
    func getUVHistory(limit: Int = 100) async throws -> [UVData] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            let response = try await client.database
                .from("uv_monitoring_data")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .order("recorded_at", ascending: false)
                .limit(limit)
                .execute()
            
            let data = response.data ?? [:]
            let uvHistory = try parseUVDataArray(from: data)
            print("🌐 [SupabaseService] ✅ Retrieved \(uvHistory.count) UV history records")
            return uvHistory
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get UV history: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseUVDataArray(from data: Any) throws -> [UVData] {
        guard let jsonData = data as? [String: Any],
              let records = jsonData["data"] as? [[String: Any]] else {
            return []
        }
        
        return records.compactMap { record in
            guard let uvIndex = record["uv_index"] as? Double,
                  let _ = record["latitude"] as? Double,
                  let _ = record["longitude"] as? Double,
                  let recordedAt = record["recorded_at"] as? Double else {
                return nil
            }
            
            return UVData(
                uvIndex: Int(uvIndex),
                date: Date(timeIntervalSince1970: recordedAt),
                cloudCover: 0.0,
                cloudCondition: "Clear"
            )
        }
    }
    
    // MARK: - Testing Methods
    
    /// Test authentication
    func testAuthentication() async -> Bool {
        print("🌐 [SupabaseService] 🧪 Testing authentication")
        
        let session = client.auth.session
        let isAuth = session != nil
        print("🌐 [SupabaseService] ✅ Authentication test: \(isAuth ? "Authenticated" : "Not authenticated")")
        return isAuth
    }
    
    /// Test connection to Supabase
    func testConnection() async -> Bool {
        print("🌐 [SupabaseService] 🧪 Testing connection")
        
        do {
            _ = try await client.database
                .from("user_locations")
                .select("id")
                .limit(1)
                .execute()
            
            print("🌐 [SupabaseService] ✅ Connection test successful")
            return true
        } catch {
            print("🌐 [SupabaseService] ❌ Connection test failed: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Types

 