import Foundation
import Supabase
import CoreLocation

// MARK: - Supabase Service
@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // MARK: - Properties
    private let client: SupabaseClient
    
    // Published properties for UI updates
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    private init() {
        // TODO: Replace with your actual Supabase credentials
        let supabaseURL = URL(string: "https://svkrlwzwnirhgbyardze.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2a3Jsd3p3bmlyaGdieWFyZHplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Mjk1OTcsImV4cCI6MjA2ODAwNTU5N30.qKyu4nuFwtU-Vsa_0JIeiQrbfMgLFF2R6EwMwLnzsc4"
        
        self.client = SupabaseClient(
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
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.isAuthenticated = session != nil
                self.currentUser = session?.user
                print("🌐 [SupabaseService] ✅ Authentication status: \(self.isAuthenticated ? "Authenticated" : "Not authenticated")")
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                print("🌐 [SupabaseService] ❌ Error checking auth status: \(error)")
            }
        }
    }
    
    /// Sign up a new user
    func signUp(email: String, password: String) async throws -> User {
        print("🌐 [SupabaseService] 📝 Signing up user: \(email)")
        
        await MainActor.run { isLoading = true }
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            await MainActor.run {
                self.currentUser = authResponse.user
                self.isAuthenticated = authResponse.user != nil
                self.isLoading = false
            }
            
            print("🌐 [SupabaseService] ✅ Sign up successful for: \(email)")
            return authResponse.user
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("🌐 [SupabaseService] ❌ Sign up failed: \(error)")
            throw error
        }
    }
    
    /// Sign in existing user
    func signIn(email: String, password: String) async throws -> User {
        print("🌐 [SupabaseService] 🔐 Signing in user: \(email)")
        
        await MainActor.run { isLoading = true }
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            await MainActor.run {
                self.currentUser = authResponse.user
                self.isAuthenticated = authResponse.user != nil
                self.isLoading = false
            }
            
            print("🌐 [SupabaseService] ✅ Sign in successful for: \(email)")
            return authResponse.user
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("🌐 [SupabaseService] ❌ Sign in failed: \(error)")
            throw error
        }
    }
    
    /// Sign out current user
    func signOut() async throws {
        print("🌐 [SupabaseService] 🚪 Signing out user")
        
        do {
            try await client.auth.signOut()
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
            
            print("🌐 [SupabaseService] ✅ Sign out successful")
        } catch {
            await MainActor.run { self.error = error }
            print("🌐 [SupabaseService] ❌ Sign out failed: \(error)")
            throw error
        }
    }
    
    // MARK: - User Location Management
    
    /// Save user location to Supabase
    func saveUserLocation(latitude: Double, longitude: Double, altitude: Double, locationName: String) async throws {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 📍 Saving location: \(locationName) (\(latitude), \(longitude))")
        
        let location: [String: Any] = [
            "user_id": user.id.uuidString,
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "location_name": locationName,
            "is_active": true
        ]
        
        do {
            try await client.database
                .from("user_locations")
                .insert(location)
                .execute()
            
            print("🌐 [SupabaseService] ✅ Location saved successfully")
        } catch {
            print("🌐 [SupabaseService] ❌ Error saving location: \(error)")
            throw error
        }
    }
    
    /// Get user's active locations
    func getUserLocations() async throws -> [UserLocation] {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 📍 Fetching user locations")
        
        do {
            let response = try await client.database
                .from("user_locations")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .eq("is_active", value: true)
                .execute()
            
            guard let data = response.data else {
                print("🌐 [SupabaseService] ⚠️ No location data found")
                return []
            }
            
            let locations = try parseUserLocations(from: data)
            print("🌐 [SupabaseService] ✅ Found \(locations.count) user locations")
            return locations
        } catch {
            print("🌐 [SupabaseService] ❌ Error fetching locations: \(error)")
            throw error
        }
    }
    
    // MARK: - UV Data Management
    
    /// Get latest UV data for current user
    func getLatestUVData() async throws -> UVMonitoringData? {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] ☀️ Fetching latest UV data")
        
        do {
            let response = try await client.database
                .from("uv_monitoring_data")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("timestamp", ascending: false)
                .limit(1)
                .execute()
            
            guard let data = response.data else {
                print("🌐 [SupabaseService] ⚠️ No UV data found")
                return nil
            }
            
            let uvData = try parseUVData(from: data)
            print("🌐 [SupabaseService] ✅ Latest UV data: \(uvData?.adjustedUVIndex ?? 0)")
            return uvData
        } catch {
            print("🌐 [SupabaseService] ❌ Error fetching UV data: \(error)")
            throw error
        }
    }
    
    /// Get UV data history for current user
    func getUVDataHistory(limit: Int = 24) async throws -> [UVMonitoringData] {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 📊 Fetching UV data history (limit: \(limit))")
        
        do {
            let response = try await client.database
                .from("uv_monitoring_data")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("timestamp", ascending: false)
                .limit(limit)
                .execute()
            
            guard let data = response.data else {
                print("🌐 [SupabaseService] ⚠️ No UV history found")
                return []
            }
            
            let uvHistory = try parseUVDataArray(from: data)
            print("🌐 [SupabaseService] ✅ Found \(uvHistory.count) UV data points")
            return uvHistory
        } catch {
            print("🌐 [SupabaseService] ❌ Error fetching UV history: \(error)")
            throw error
        }
    }
    
    /// Save UV monitoring data to Supabase
    func saveUVData(_ uvData: UVMonitoringData) async throws {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 💾 Saving UV data: UV \(uvData.adjustedUVIndex)")
        
        let data: [String: Any] = [
            "user_id": user.id.uuidString,
            "location_id": uvData.locationId.uuidString,
            "base_uv_index": uvData.baseUVIndex,
            "adjusted_uv_index": uvData.adjustedUVIndex,
            "risk_score": uvData.riskScore,
            "risk_level": uvData.riskLevel,
            "environmental_factors": try JSONSerialization.data(withJSONObject: uvData.environmentalFactors.toDictionary()),
            "risk_factors": uvData.riskFactors?.map { $0.toDictionary() },
            "recommendations": uvData.recommendations?.map { $0.toDictionary() },
            "cloud_cover": uvData.cloudCover,
            "cloud_condition": uvData.cloudCondition,
            "time_to_burn": uvData.timeToBurn
        ]
        
        do {
            try await client.database
                .from("uv_monitoring_data")
                .insert(data)
                .execute()
            
            print("🌐 [SupabaseService] ✅ UV data saved successfully")
        } catch {
            print("🌐 [SupabaseService] ❌ Error saving UV data: \(error)")
            throw error
        }
    }
    
    // MARK: - User Preferences
    
    /// Get user preferences
    func getUserPreferences() async throws -> UserPreferences? {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] ⚙️ Fetching user preferences")
        
        do {
            let response = try await client.database
                .from("user_preferences")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
            
            guard let data = response.data else {
                print("🌐 [SupabaseService] ⚠️ No preferences found")
                return nil
            }
            
            let preferences = try parseUserPreferences(from: data)
            print("🌐 [SupabaseService] ✅ User preferences loaded")
            return preferences
        } catch {
            print("🌐 [SupabaseService] ❌ Error fetching preferences: \(error)")
            throw error
        }
    }
    
    /// Save user preferences
    func saveUserPreferences(_ preferences: UserPreferences) async throws {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 💾 Saving user preferences")
        
        let data: [String: Any] = [
            "user_id": user.id.uuidString,
            "uv_change_threshold": preferences.uvChangeThreshold,
            "minimum_risk_level": preferences.minimumRiskLevel,
            "notification_enabled": preferences.notificationEnabled,
            "widget_update_interval": preferences.widgetUpdateInterval
        ]
        
        do {
            try await client.database
                .from("user_preferences")
                .upsert(data)
                .execute()
            
            print("🌐 [SupabaseService] ✅ User preferences saved")
        } catch {
            print("🌐 [SupabaseService] ❌ Error saving preferences: \(error)")
            throw error
        }
    }
    
    // MARK: - Notifications
    
    /// Get pending notifications for current user
    func getPendingNotifications() async throws -> [ServerNotification] {
        guard isAuthenticated, let user = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        print("🌐 [SupabaseService] 🔔 Fetching pending notifications")
        
        do {
            let response = try await client.database
                .from("notification_history")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .eq("delivered", value: false)
                .order("sent_at", ascending: false)
                .execute()
            
            guard let data = response.data else {
                print("🌐 [SupabaseService] ⚠️ No pending notifications")
                return []
            }
            
            let notifications = try parseNotifications(from: data)
            print("🌐 [SupabaseService] ✅ Found \(notifications.count) pending notifications")
            return notifications
        } catch {
            print("🌐 [SupabaseService] ❌ Error fetching notifications: \(error)")
            throw error
        }
    }
    
    /// Mark notification as delivered
    func markNotificationAsDelivered(_ notificationId: UUID) async throws {
        print("🌐 [SupabaseService] ✅ Marking notification as delivered: \(notificationId)")
        
        do {
            try await client.database
                .from("notification_history")
                .update(["delivered": true])
                .eq("id", value: notificationId.uuidString)
                .execute()
            
            print("🌐 [SupabaseService] ✅ Notification marked as delivered")
        } catch {
            print("🌐 [SupabaseService] ❌ Error marking notification: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Parsing Methods
    
    private func parseUserLocations(from data: Data) throws -> [UserLocation] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([UserLocation].self, from: data)
    }
    
    private func parseUVData(from data: Data) throws -> UVMonitoringData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let array = try decoder.decode([UVMonitoringData].self, from: data)
        return array.first
    }
    
    private func parseUVDataArray(from data: Data) throws -> [UVMonitoringData] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([UVMonitoringData].self, from: data)
    }
    
    private func parseUserPreferences(from data: Data) throws -> UserPreferences? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let array = try decoder.decode([UserPreferences].self, from: data)
        return array.first
    }
    
    private func parseNotifications(from data: Data) throws -> [ServerNotification] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([ServerNotification].self, from: data)
    }
    
    // MARK: - Testing Methods
    
    /// Test Supabase connection
    func testConnection() async -> Bool {
        print("🌐 [SupabaseService] 🧪 Testing Supabase connection")
        
        do {
            let response = try await client.database
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
    
    /// Test authentication
    func testAuthentication() async -> Bool {
        print("🌐 [SupabaseService] 🧪 Testing authentication")
        
        do {
            let session = try await client.auth.session
            let isAuth = session != nil
            print("🌐 [SupabaseService] ✅ Authentication test: \(isAuth ? "Authenticated" : "Not authenticated")")
            return isAuth
        } catch {
            print("🌐 [SupabaseService] ❌ Authentication test failed: \(error)")
            return false
        }
    }
}

// MARK: - Custom Errors
enum SupabaseError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid data received"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Data Models for Supabase

struct UserLocation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let locationName: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, altitude, locationName
        case userId = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UVMonitoringData: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let locationId: UUID
    let timestamp: Date
    let baseUVIndex: Int
    let adjustedUVIndex: Int
    let riskScore: Double
    let riskLevel: String
    let environmentalFactors: EnvironmentalFactors
    let riskFactors: [RiskFactor]?
    let recommendations: [Recommendation]?
    let cloudCover: Double?
    let cloudCondition: String?
    let timeToBurn: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, baseUVIndex, adjustedUVIndex, riskScore, riskLevel
        case environmentalFactors, riskFactors, recommendations, cloudCover, cloudCondition, timeToBurn
        case userId = "user_id"
        case locationId = "location_id"
        case createdAt = "created_at"
    }
}

struct UserPreferences: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let uvChangeThreshold: Int
    let minimumRiskLevel: String
    let notificationEnabled: Bool
    let widgetUpdateInterval: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, uvChangeThreshold, minimumRiskLevel, notificationEnabled, widgetUpdateInterval
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ServerNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let notificationType: String
    let message: String
    let uvData: [String: Any]?
    let sentAt: Date
    let delivered: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, notificationType, message, sentAt, delivered
        case userId = "user_id"
        case uvData = "uv_data"
    }
}

// MARK: - Extensions for Dictionary Conversion

extension EnvironmentalFactors {
    func toDictionary() -> [String: Any] {
        return [
            "altitude": altitude,
            "snowConditions": [
                "hasRecentSnowfall": snowConditions.hasRecentSnowfall,
                "snowDepth": snowConditions.snowDepth,
                "snowCoverage": snowConditions.snowCoverage,
                "snowAge": snowConditions.snowAge,
                "snowType": snowConditions.snowType.rawValue
            ],
            "waterProximity": [
                "distanceToWater": waterProximity.distanceToWater,
                "waterBodyType": waterProximity.waterBodyType.rawValue,
                "nearestWaterBody": waterProximity.nearestWaterBody?.toDictionary()
            ],
            "terrainType": terrainType.rawValue,
            "seasonalFactors": [
                "season": seasonalFactors.season.rawValue,
                "dayOfYear": seasonalFactors.dayOfYear,
                "isWinterSolstice": seasonalFactors.isWinterSolstice,
                "isSummerSolstice": seasonalFactors.isSummerSolstice,
                "isEquinox": seasonalFactors.isEquinox,
                "seasonalUVMultiplier": seasonalFactors.seasonalUVMultiplier
            ]
        ]
    }
}

extension RiskFactor {
    func toDictionary() -> [String: Any] {
        return [
            "type": type.rawValue,
            "severity": severity.rawValue,
            "description": description,
            "impact": impact,
            "mitigation": mitigation
        ]
    }
}

extension Recommendation {
    func toDictionary() -> [String: Any] {
        return [
            "type": type.rawValue,
            "priority": priority.rawValue,
            "title": title,
            "description": description,
            "actionItems": actionItems
        ]
    }
}

extension WaterProximity.NearestWaterBody {
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "size": size.rawValue,
            "distance": distance
        ]
    }
} 