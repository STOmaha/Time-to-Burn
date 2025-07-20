import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showEmailAuth = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.3),
                        Color.orange.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // App Logo and Title
                        VStack(spacing: 20) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.orange)
                                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Text("Time to Burn")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Smart UV Protection")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                        
                        // Authentication Options
                        VStack(spacing: 20) {
                            // Sign in with Apple
                            SignInWithAppleButton(
                                onRequest: { request in
                                    request.requestedScopes = [.fullName, .email]
                                },
                                onCompletion: { result in
                                    handleAppleSignIn(result)
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(25)
                            
                            // Sign in with Google
                            Button(action: handleGoogleSignIn) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.title2)
                                    Text("Continue with Google")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(25)
                            }
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text("or")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            
                            // Email authentication toggle
                            Button(action: { showEmailAuth.toggle() }) {
                                Text(showEmailAuth ? "Use social sign-in" : "Sign in with email")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                            }
                            
                            // Email authentication form
                            if showEmailAuth {
                                EmailAuthForm(
                                    email: $email,
                                    password: $password,
                                    isSignUp: $isSignUp,
                                    isLoading: $isLoading,
                                    onSubmit: handleEmailAuth
                                )
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Loading indicator
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding()
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(supabaseService.$error) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        // Get the identity token
                        guard let identityToken = appleIDCredential.identityToken,
                              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                            throw NSError(domain: "AuthenticationError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid identity token"])
                        }
                        
                        // Sign in with Supabase
                        try await supabaseService.signInWithApple(identityToken: identityTokenString)
                        
                        await MainActor.run {
                            isLoading = false
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                            isLoading = false
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        
        Task {
            do {
                try await supabaseService.signInWithGoogle()
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func handleEmailAuth() {
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    _ = try await supabaseService.signUp(email: email, password: password)
                } else {
                    _ = try await supabaseService.signIn(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Email Authentication Form
struct EmailAuthForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var isLoading: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            // Email field
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            // Password field
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            // Sign up/Sign in toggle
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            // Submit button
            Button(action: onSubmit) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity((email.isEmpty || password.isEmpty || isLoading) ? 0.6 : 1.0)
        }
    }
}

// MARK: - Preview
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
} 