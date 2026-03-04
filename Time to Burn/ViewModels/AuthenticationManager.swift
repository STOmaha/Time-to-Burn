import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import Supabase

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var showAuthentication = false
    @Published var error: Error?
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("🔐 [AuthenticationManager] 🚀 Initializing...")
        
        // Setup auth state listener
        setupAuthenticationListener()
        
        // Check initial authentication status
        Task {
            await checkAuthenticationStatus()
        }
    }
    
    // MARK: - Authentication Status Management
    
    private func setupAuthenticationListener() {
        print("🔐 [AuthenticationManager] Setting up authentication listener...")

        // Listen for authentication state changes from SupabaseService via Combine
        // NOTE: We only use ONE listener (Combine) to prevent duplicate state change handling
        // The SupabaseService.setupAuthListener() is called separately for its internal state
        supabaseService.$isAuthenticated
            .removeDuplicates() // Prevent duplicate emissions
            .sink { [weak self] isAuthenticated in
                print("🔐 [AuthenticationManager] 🔔 Auth state changed: \(isAuthenticated)")
                Task { @MainActor in
                    guard let self = self else { return }

                    // Only process if this is actually a change
                    guard self.isAuthenticated != isAuthenticated else { return }

                    self.isAuthenticated = isAuthenticated
                    self.currentUser = self.supabaseService.currentUser

                    if isAuthenticated {
                        print("🔐 [AuthenticationManager] ✅ User authenticated via state listener")
                        print("🔐 [AuthenticationManager] User: \(self.supabaseService.currentUser?.email ?? "unknown")")
                        self.showAuthentication = false
                        // NOTE: Push notification permission is requested during onboarding, not here
                        // to avoid duplicate permission requests
                    } else {
                        print("🔐 [AuthenticationManager] ❌ User not authenticated (state listener)")
                        self.showAuthentication = true
                    }
                }
            }
            .store(in: &cancellables)

        // Setup internal auth state listener in SupabaseService (for its own @Published state)
        supabaseService.setupAuthListener()
    }
    
    private func checkAuthenticationStatus() async {
        print("🔐 [AuthenticationManager] 🔍 Checking authentication status...")
        
        await MainActor.run {
            isLoading = true
        }
        
        // Check session in SupabaseService
        await supabaseService.checkSession()
        
        await MainActor.run {
            isAuthenticated = supabaseService.isAuthenticated
            currentUser = supabaseService.currentUser
            showAuthentication = !isAuthenticated
            isLoading = false
        }
        
        if isAuthenticated {
            print("🔐 [AuthenticationManager] ✅ Authentication status confirmed")
        } else {
            print("🔐 [AuthenticationManager] ℹ️ No active session")
        }
    }
    
    // MARK: - Authentication Methods

    /// Sign in with Apple
    func signInWithApple(authorization: ASAuthorization) async throws {
        print("🔐 [AuthenticationManager] ====================================")
        print("🔐 [AuthenticationManager] 🍎 Sign In with Apple STARTED")
        print("🔐 [AuthenticationManager] ====================================")

        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthenticationError.invalidToken
        }

        // For native iOS Sign in with Apple, we don't pass a nonce
        // Nonce is only used for web-based OAuth flows
        do {
            try await supabaseService.signInWithApple(idToken: idTokenString)

            await MainActor.run {
                isAuthenticated = true
                currentUser = supabaseService.currentUser
                showAuthentication = false
            }

            print("🔐 [AuthenticationManager] ✅ Apple Sign In successful")

            // Run debug test to verify database connection and profile creation
            print("🔐 [AuthenticationManager] 🔧 Running connection debug test...")
            await supabaseService.debugConnectionTest()

        } catch {
            print("🔐 [AuthenticationManager] ❌ Apple Sign In failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws {
        print("🔐 [AuthenticationManager] 📧 Email Sign In...")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            try await supabaseService.signInWithEmail(email: email, password: password)
            
            await MainActor.run {
                isAuthenticated = true
                currentUser = supabaseService.currentUser
                showAuthentication = false
            }
            
            print("🔐 [AuthenticationManager] ✅ Email Sign In successful")
            
        } catch {
            print("🔐 [AuthenticationManager] ❌ Email Sign In failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String, name: String) async throws {
        print("🔐 [AuthenticationManager] 📝 Email Sign Up...")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            try await supabaseService.signUp(email: email, password: password, fullName: name)
            
            await MainActor.run {
                isAuthenticated = true
                currentUser = supabaseService.currentUser
                showAuthentication = false
            }
            
            print("🔐 [AuthenticationManager] ✅ Email Sign Up successful")
            
        } catch {
            print("🔐 [AuthenticationManager] ❌ Email Sign Up failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    /// Sign out
    func signOut() async throws {
        print("🔐 [AuthenticationManager] 👋 Signing out...")
        
        do {
            try await supabaseService.signOut()
            
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                showAuthentication = true
            }
            
            // Reset BackgroundSyncService state
            BackgroundSyncService.shared.reset()
            
            print("🔐 [AuthenticationManager] ✅ Sign out successful")
            
        } catch {
            print("🔐 [AuthenticationManager] ❌ Sign out failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
            throw error
        }
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
        guard let metadata = currentUser?.userMetadata,
              let fullName = metadata["full_name"] else {
            return nil
        }
        // Handle AnyJSON type from Supabase
        if case .string(let name) = fullName {
            return name
        }
        return nil
    }
    
    var userId: UUID? {
        return currentUser?.id
    }
    
    // MARK: - Push Notifications
    
    private func requestPushNotificationPermission() async {
        print("🔐 [AuthenticationManager] 🔔 Requesting push notification permission...")
        
        let granted = await NotificationManager.shared.requestNotificationPermission()
        
        if granted {
            print("🔐 [AuthenticationManager] ✅ Push notification permission granted")
        } else {
            print("🔐 [AuthenticationManager] ❌ Push notification permission denied")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate a secure random nonce for Sign in with Apple
    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

// MARK: - Error Types

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case invalidToken
    case networkError
    case userNotFound
    case emailAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .invalidToken:
            return "Invalid authentication token"
        case .networkError:
            return "Network connection error"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "Email address already in use"
        }
    }
}
