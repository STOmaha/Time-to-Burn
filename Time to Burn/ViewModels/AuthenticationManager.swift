// import Foundation
// import SwiftUI
// import Combine
// import AuthenticationServices

// // Local User type (Supabase removed)
// struct User {
//     let id: UUID
//     let email: String?
//     let createdAt: Date
//     let userMetadata: [String: Any]?
// }

// @MainActor
// class AuthenticationManager: ObservableObject {
//     static let shared = AuthenticationManager()
    
//     @Published var isAuthenticated = false
//     @Published var currentUser: User?
//     @Published var isLoading = false
//     @Published var showAuthentication = false
    
//     // SupabaseService removed - using local authentication only
    
//     private init() {
//         print("🔐 [AuthenticationManager] 🚀 Initializing...")
        
//         // For local-only mode, set authenticated to true by default
//         isAuthenticated = true
//         currentUser = User(
//             id: UUID(),
//             email: "local@user.com",
//             createdAt: Date(),
//             userMetadata: ["full_name": "Local User"]
//         )
//         showAuthentication = false
        
//         print("🔐 [AuthenticationManager] ✅ Local authentication mode - user authenticated")
        
//         // TODO: Re-enable Supabase authentication after fixing server issues
//         /*
//         // Listen for authentication changes
//         setupAuthenticationListener()
        
//         // Check initial authentication status
//         Task {
//             await checkAuthenticationStatus()
//         }
//         */
//     }
    
//     // MARK: - Authentication Status Management
    
//     private func setupAuthenticationListener() {
//         // TODO: Re-enable after fixing server issues
//         /*
//         // Listen for authentication state changes
//         supabaseService.$isAuthenticated
//             .sink { [weak self] isAuthenticated in
//                 Task { @MainActor in
//                     self?.isAuthenticated = isAuthenticated
//                     self?.currentUser = self?.supabaseService.currentUser
                    
//                     if isAuthenticated {
//                         print("🔐 [AuthenticationManager] ✅ User authenticated")
//                         self?.showAuthentication = false
                        
//                         // Create user profile if needed
//                         await self?.createUserProfileIfNeeded()
                        
//                         // Request push notification permission after authentication
//                         await self?.requestPushNotificationPermission()
//                     } else {
//                         print("🔐 [AuthenticationManager] ❌ User not authenticated")
//                         self?.showAuthentication = true
//                     }
//                 }
//             }
//             .store(in: &cancellables)
//         */
//     }
    
//     private func checkAuthenticationStatus() async {
//         print("🔐 [AuthenticationManager] 🔍 Checking authentication status...")
        
//         await MainActor.run {
//             isLoading = true
//         }
        
//         // Local-only mode - always authenticated
//         isAuthenticated = true
//         currentUser = User(
//             id: UUID(),
//             email: "local@user.com",
//             createdAt: Date(),
//             userMetadata: ["full_name": "Local User"]
//         )
//         showAuthentication = false
        
//         await MainActor.run {
//             isLoading = false
//         }
        
//         print("🔐 [AuthenticationManager] ✅ Local authentication status confirmed")
//     }
    
//     // MARK: - User Profile Management
    
//     private func createUserProfileIfNeeded() async {
//         print("🔐 [AuthenticationManager] 👤 Creating user profile if needed...")
        
//         guard let user = currentUser else {
//             print("🔐 [AuthenticationManager] ❌ No current user")
//             return
//         }
        
//         // TODO: Re-enable after fixing server issues
//         /*
//         do {
//             try await supabaseService.createUserProfile(userId: user.id.uuidString)
//             print("🔐 [AuthenticationManager] ✅ User profile created/verified")
//         } catch {
//             print("🔐 [AuthenticationManager] ❌ Failed to create user profile: \(error)")
//         }
//         */
//     }
    
//     // MARK: - Authentication Methods
    
//     func signInWithApple() async throws {
//         print("🔐 [AuthenticationManager] 🍎 Sign In with Apple...")
        
//         await MainActor.run {
//             isLoading = true
//         }
        
//         // Simulate network delay
//         try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
//         // Create local user
//         let user = User(
//             id: UUID(),
//             email: "apple@user.com",
//             createdAt: Date(),
//             userMetadata: ["full_name": "Apple User"]
//         )
        
//         await MainActor.run {
//             isAuthenticated = true
//             currentUser = user
//             showAuthentication = false
//             isLoading = false
//         }
        
//         print("🔐 [AuthenticationManager] ✅ Local Apple Sign In successful")
//     }
    
//     func signInWithEmail(email: String, password: String) async throws {
//         print("🔐 [AuthenticationManager] 📧 Local Email Sign In...")
        
//         await MainActor.run {
//             isLoading = true
//         }
        
//         // Simulate network delay
//         try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
//         // Create local user
//         let user = User(
//             id: UUID(),
//             email: email,
//             createdAt: Date(),
//             userMetadata: ["full_name": "Email User"]
//         )
        
//         await MainActor.run {
//             isAuthenticated = true
//             currentUser = user
//             showAuthentication = false
//             isLoading = false
//         }
        
//         print("🔐 [AuthenticationManager] ✅ Local Email Sign In successful")
//     }
    
//     func signUp(email: String, password: String, name: String) async throws {
//         print("🔐 [AuthenticationManager] 📝 Local Email Sign Up...")
        
//         await MainActor.run {
//             isLoading = true
//         }
        
//         // Simulate network delay
//         try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
//         // Create local user
//         let user = User(
//             id: UUID(),
//             email: email,
//             createdAt: Date(),
//             userMetadata: ["full_name": name]
//         )
        
//         await MainActor.run {
//             isAuthenticated = true
//             currentUser = user
//             showAuthentication = false
//             isLoading = false
//         }
        
//         print("🔐 [AuthenticationManager] ✅ Local Email Sign Up successful")
//     }
    
//     // MARK: - Authentication Flow Control
    
//     func showAuthenticationView() {
//         showAuthentication = true
//     }
    
//     func hideAuthenticationView() {
//         showAuthentication = false
//     }
    
//     // MARK: - User Data Access
    
//     var userEmail: String? {
//         return currentUser?.email
//     }
    
//     var userName: String? {
//         return currentUser?.userMetadata?["full_name"] as? String
//     }
    
//     var userId: UUID? {
//         return currentUser?.id
//     }
    
//     // MARK: - Testing Methods
    
//     func testAuthentication() async -> Bool {
//         print("🔐 [AuthenticationManager] 🧪 Testing local authentication...")
        
//         // Local-only mode - always authenticated
//         let isAuth = true
        
//         print("🔐 [AuthenticationManager] 🧪 Authentication: \(isAuth ? "✅" : "❌")")
        
//         return isAuth
//     }
    
//     // MARK: - Push Notifications
    
//     private func requestPushNotificationPermission() async {
//         print("🔐 [AuthenticationManager] 🔔 Requesting push notification permission...")
        
//         let pushNotificationService = PushNotificationService.shared
//         let granted = await pushNotificationService.requestPermission()
        
//         if granted {
//             print("🔐 [AuthenticationManager] ✅ Push notification permission granted")
//         } else {
//             print("🔐 [AuthenticationManager] ❌ Push notification permission denied")
//         }
//     }
    
//     // MARK: - Private Properties
    
//     // TODO: Re-enable after fixing server issues
//     // private var cancellables = Set<AnyCancellable>()
// } 