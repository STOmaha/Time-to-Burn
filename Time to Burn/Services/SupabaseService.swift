import Foundation
import CoreLocation
import Supabase
import UIKit

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

    // MARK: - User Type Conversion

    private func convertSupabaseUser(_ supabaseUser: Auth.User?) -> User? {
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
        // Your actual Supabase credentials
        let supabaseURL = URL(string: "https://svkrlwzwnirhgbyardze.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2a3Jsd3p3bmlyaGdieWFyZHplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Mjk1OTcsImV4cCI6MjA2ODAwNTU5N30.qKyu4nuFwtU-Vsa_0JIeiQrbfMgLFF2R6EwMwLnzsc4"

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )

        // Check authentication status on initialization
        Task {
            await checkAuthenticationStatus()
        }
    }

    /// Check if user is currently authenticated
    private func checkAuthenticationStatus() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.isAuthenticated = session.user != nil
                self.currentUser = self.convertSupabaseUser(session.user)
                print("🌐 [SupabaseService] ✅ Authentication status: \(self.isAuthenticated ? "Authenticated" : "Not authenticated")")
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                print("🌐 [SupabaseService] ❌ Authentication check failed: \(error)")
            }
        }
    }

    /// Sign in a user
    func signIn(email: String, password: String) async throws -> User {
        await MainActor.run { self.isLoading = true }
        do {
            let authResponse = try await client.auth.signIn(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                self.isLoading = false
                self.error = nil
                print("🌐 [SupabaseService] ✅ Sign in successful")
            }
            guard let user = self.currentUser else {
                throw NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found after sign in"])
            }
            return user
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error
                print("🌐 [SupabaseService] ❌ Sign in failed: \(error)")
            }
            throw error
        }
    }

    /// Sign up a new user
    func signUp(email: String, password: String, name: String) async throws -> User {
        await MainActor.run { self.isLoading = true }
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": AnyJSON.string(name)]
            )

            await MainActor.run {
                self.isAuthenticated = authResponse.user != nil
                self.currentUser = self.convertSupabaseUser(authResponse.user)
                self.isLoading = false
                self.error = nil
                print("🌐 [SupabaseService] ✅ Sign up successful")
            }
            guard let user = self.currentUser else {
                throw NSError(domain: "SupabaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found after sign up"])
            }
            return user
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error
                print("🌐 [SupabaseService] ❌ Sign up failed: \(error)")
            }
            throw error
        }
    }

    /// Sign out the current user
    func signOut() async throws {
        await MainActor.run { self.isLoading = true }
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isLoading = false
                self.error = nil
                print("🌐 [SupabaseService] ✅ Sign out successful")
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
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
                credentials: .init(provider: .apple, idToken: identityToken)
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
                credentials: .init(provider: .google, idToken: "mock_google_token")
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

        let profileData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "email": .string(email),
            "full_name": .string(name),
            "created_at": .double(Double(Date().timeIntervalSince1970))
        ]

        do {
            _ = try await client
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

        let locationData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "recorded_at": .double(Double(Date().timeIntervalSince1970))
        ]

        do {
            _ = try await client
                .from("user_locations")
                .insert(locationData)
                .execute()
            print("🌐 [SupabaseService] ✅ User location saved successfully")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save user location: \(error)")
            throw error
        }
    }

               /// Register device token for push notifications
           func registerDeviceToken(_ token: String) async throws {
               guard let userId = currentUser?.id else {
                   throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
               }
               
               print("🌐 [SupabaseService] 📱 Registering device token...")
               
               struct DeviceData: Codable {
                   let user_id: String
                   let device_token: String
                   let platform: String
                   let app_version: String
                   let device_model: String
                   let os_version: String
                   let created_at: TimeInterval
                   let updated_at: TimeInterval
               }
               
               let deviceData = DeviceData(
                   user_id: userId.uuidString,
                   device_token: token,
                   platform: "ios",
                   app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                   device_model: UIDevice.current.model,
                   os_version: UIDevice.current.systemVersion,
                   created_at: Date().timeIntervalSince1970,
                   updated_at: Date().timeIntervalSince1970
               )
               
               do {
                   _ = try await client.database
                       .from("user_devices")
                       .upsert(deviceData)
                       .execute()
                   
                   print("🌐 [SupabaseService] ✅ Device token registered successfully")
               } catch {
                   print("🌐 [SupabaseService] ❌ Failed to register device token: \(error)")
                   throw error
               }
           }
           
           /// Save UV data
           func saveUVData(uvData: UVData) async throws {
               guard let userId = currentUser?.id else {
                   throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
               }

        let uvDataDict: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "uv_index": .double(Double(uvData.uvIndex)),
            "date": .string(ISO8601DateFormatter().string(from: uvData.date)),
            "cloud_cover": .double(uvData.cloudCover),
            "cloud_condition": .string(uvData.cloudCondition),
            "recorded_at": .double(Double(Date().timeIntervalSince1970))
        ]

        do {
            _ = try await client
                .from("uv_data")
                .insert(uvDataDict)
                .execute()
            print("🌐 [SupabaseService] ✅ UV data saved successfully")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save UV data: \(error)")
            throw error
        }
    }

    /// Save exposure session
    func saveExposureSession(session: UVExposureSession) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let sessionData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "start_time": .string(ISO8601DateFormatter().string(from: session.startTime)),
            "end_time": session.endTime != nil ? .string(ISO8601DateFormatter().string(from: session.endTime!)) : .null,
            "duration_minutes": .double(Double(session.durationMinutes)),
            "uv_index": .double(session.uvIndex),
            "latitude": .double(session.latitude),
            "longitude": .double(session.longitude),
            "created_at": .double(Double(Date().timeIntervalSince1970))
        ]

        do {
            _ = try await client
                .from("exposure_sessions")
                .insert(sessionData)
                .execute()
            print("🌐 [SupabaseService] ✅ Exposure session saved successfully")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to save exposure session: \(error)")
            throw error
        }
    }

    /// Get user's exposure history
    func getExposureHistory() async throws -> [UVExposureSession] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        do {
            let response = try await client
                .from("exposure_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()

            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let sessions = try decoder.decode([UVExposureSession].self, from: data)
            print("🌐 [SupabaseService] ✅ Retrieved \(sessions.count) exposure sessions")
            return sessions
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get exposure history: \(error)")
            throw error
        }
    }

    /// Get user's UV data history
    func getUVDataHistory() async throws -> [UVData] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        do {
            let response = try await client
                .from("uv_data")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("recorded_at", ascending: false)
                .limit(100)
                .execute()

            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let uvDataArray = try decoder.decode([UVData].self, from: data)
            print("🌐 [SupabaseService] ✅ Retrieved \(uvDataArray.count) UV data points")
            return uvDataArray
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get UV data history: \(error)")
            throw error
        }
    }

    /// Create default user preferences
    func createDefaultUserPreferences() async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let preferencesData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "skin_type": .string("type_3"), // Default skin type
            "sunscreen_spf": .double(30),
            "notifications_enabled": .bool(true),
            "created_at": .double(Double(Date().timeIntervalSince1970))
        ]

        do {
            _ = try await client
                .from("user_preferences")
                .upsert(preferencesData)
                .execute()
            print("🌐 [SupabaseService] ✅ Default user preferences created")
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to create default user preferences: \(error)")
            throw error
        }
    }

    /// Get user profile
    func getUserProfile() async throws -> [String: Any]? {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        do {
            let response = try await client
                .from("user_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()

            let data = response.data
            
            // Convert Data to [String: Any] using JSONSerialization
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
            return nil
        } catch {
            print("🌐 [SupabaseService] ❌ Failed to get user profile: \(error)")
            throw error
        }
    }
}

// MARK: - Supporting Types

 