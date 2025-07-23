import Foundation
import SwiftUI

// Local User type that matches Supabase User interface
struct User {
    let id: UUID
    let email: String?
    let createdAt: Date
    let userMetadata: [String: Any]?
}

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var showAuthentication = false
    
    private let supabaseService = SupabaseService.shared
    
    private init() {
        print("🔐 [AuthenticationManager] 🚀 Initializing...")
        
        // Listen for authentication changes
        setupAuthenticationListener()
        
        // Check initial authentication status
        Task {
            await checkAuthenticationStatus()
        }
    }
    
    // MARK: - Authentication Status Management
    
    private func setupAuthenticationListener() {
        // Listen for authentication state changes
        supabaseService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    self?.isAuthenticated = isAuthenticated
                    self?.currentUser = self?.supabaseService.currentUser
                    
                    if isAuthenticated {
                        print("🔐 [AuthenticationManager] ✅ User authenticated")
                        self?.showAuthentication = false
                        
                        // Create user profile if needed
                        await self?.createUserProfileIfNeeded()
                        
                        // Request push notification permission after authentication
                        await self?.requestPushNotificationPermission()
                    } else {
                        print("🔐 [AuthenticationManager] ❌ User not authenticated")
                        self?.showAuthentication = true
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAuthenticationStatus() async {
        print("🔐 [AuthenticationManager] 🔍 Checking authentication status...")
        
        await MainActor.run {
            isLoading = true
        }
        
        // The SupabaseService already checks authentication on init
        // We just need to sync our state
        isAuthenticated = supabaseService.isAuthenticated
        currentUser = supabaseService.currentUser
        
        if isAuthenticated {
            await createUserProfileIfNeeded()
            await requestPushNotificationPermission()
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - User Profile Management
    
    private func createUserProfileIfNeeded() async {
        guard let user = currentUser else { return }
        
        print("🔐 [AuthenticationManager] 👤 Creating user profile if needed...")
        
        do {
            // Check if user profile exists
            let existingProfile = try await supabaseService.getUserProfile()
            
            if existingProfile == nil {
                // Create new user profile
                try await supabaseService.createUserProfile(
                    email: user.email ?? "",
                    name: user.userMetadata?["full_name"] as? String ?? "User"
                )
                
                // Create default user preferences
                try await supabaseService.createDefaultUserPreferences()
                
                print("🔐 [AuthenticationManager] ✅ User profile and preferences created")
            } else {
                print("🔐 [AuthenticationManager] ✅ User profile already exists")
            }
        } catch {
            print("🔐 [AuthenticationManager] ❌ Error creating user profile: \(error)")
        }
    }
    
    // MARK: - Public Authentication Methods
    
    func signOut() async {
        print("🔐 [AuthenticationManager] 🚪 Signing out user...")
        
        do {
            try await supabaseService.signOut()
            
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                showAuthentication = true
            }
            
            print("🔐 [AuthenticationManager] ✅ Sign out successful")
        } catch {
            print("🔐 [AuthenticationManager] ❌ Sign out failed: \(error)")
        }
    }
    
    func refreshAuthentication() async {
        print("🔐 [AuthenticationManager] 🔄 Refreshing authentication...")
        await checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Flow Control
    
    func showAuthenticationView() {
        showAuthentication = true
    }
    
    func hideAuthenticationView() {
        showAuthentication = false
    }
    
    // MARK: - User Data Access
    
    var userEmail: String? {
        return currentUser?.email
    }
    
    var userName: String? {
        return currentUser?.userMetadata?["full_name"] as? String
    }
    
    var userId: UUID? {
        return currentUser?.id
    }
    
    // MARK: - Testing Methods
    
    func testAuthentication() async -> Bool {
        print("🔐 [AuthenticationManager] 🧪 Testing authentication...")
        
        // For real Supabase integration, we can check if we have a valid session
        let isAuth = supabaseService.isAuthenticated
        
        print("🔐 [AuthenticationManager] 🧪 Authentication: \(isAuth ? "✅" : "❌")")
        
        return isAuth
    }
    
    // MARK: - Push Notifications
    
    private func requestPushNotificationPermission() async {
        print("🔐 [AuthenticationManager] 🔔 Requesting push notification permission...")
        
        let pushNotificationService = PushNotificationService.shared
        let granted = await pushNotificationService.requestPermission()
        
        if granted {
            print("🔐 [AuthenticationManager] ✅ Push notification permission granted")
        } else {
            print("🔐 [AuthenticationManager] ❌ Push notification permission denied")
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Combine Import
import Combine 