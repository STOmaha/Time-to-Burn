// import SwiftUI
// import AuthenticationServices

// struct AuthenticationView: View {
//     @EnvironmentObject var authenticationManager: AuthenticationManager
//     @Environment(\.dismiss) private var dismiss
    
//     @State private var email = ""
//     @State private var password = ""
//     @State private var name = ""
//     @State private var isSignUp = false
//     @State private var showAlert = false
//     @State private var alertMessage = ""
    
//     var body: some View {
//         NavigationView {
//             VStack(spacing: 30) {
//                 // Header
//                 VStack(spacing: 10) {
//                     Image(systemName: "sun.max.fill")
//                         .font(.system(size: 60))
//                         .foregroundColor(.orange)
                    
//                     Text("Time to Burn")
//                         .font(.largeTitle)
//                         .fontWeight(.bold)
                    
//                     Text(isSignUp ? "Create your account" : "Welcome back")
//                         .font(.title2)
//                         .foregroundColor(.secondary)
//                 }
                
//                 // Form
//                 VStack(spacing: 20) {
//                     if isSignUp {
//                         TextField("Full Name", text: $name)
//                             .textFieldStyle(RoundedBorderTextFieldStyle())
//                     }
                    
//                     TextField("Email", text: $email)
//                         .textFieldStyle(RoundedBorderTextFieldStyle())
//                         .keyboardType(.emailAddress)
//                         .autocapitalization(.none)
                    
//                     SecureField("Password", text: $password)
//                         .textFieldStyle(RoundedBorderTextFieldStyle())
                    
//                     Button(action: handleSubmit) {
//                         HStack {
//                             if authenticationManager.isLoading {
//                                 ProgressView()
//                                     .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                     .scaleEffect(0.8)
//                             }
//                             Text(isSignUp ? "Sign Up" : "Sign In")
//                                 .fontWeight(.semibold)
//                         }
//                         .frame(maxWidth: .infinity)
//                         .padding()
//                         .background(Color.blue)
//                         .foregroundColor(.white)
//                         .cornerRadius(10)
//                     }
//                     .disabled(authenticationManager.isLoading)
                    
//                     // Apple Sign In
//                     SignInWithAppleButton(
//                         onRequest: { request in
//                             request.requestedScopes = [.fullName, .email]
//                         },
//                         onCompletion: { result in
//                             handleAppleSignIn(result)
//                         }
//                     )
//                     .frame(height: 50)
//                     .cornerRadius(10)
//                 }
                
//                 // Toggle between sign in and sign up
//                 Button(action: { isSignUp.toggle() }) {
//                     Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
//                         .foregroundColor(.blue)
//                 }
                
//                 Spacer()
//             }
//             .padding()
//             .navigationBarHidden(true)
//             .alert("Authentication", isPresented: $showAlert) {
//                 Button("OK") { }
//             } message: {
//                 Text(alertMessage)
//             }
//         }
//     }
    
//     private func handleSubmit() {
//         guard !email.isEmpty, !password.isEmpty else {
//             alertMessage = "Please fill in all fields"
//             showAlert = true
//             return
//         }
        
//         if isSignUp {
//             guard !name.isEmpty else {
//                 alertMessage = "Please enter your name"
//                 showAlert = true
//                 return
//             }
            
//             Task {
//                 do {
//                     try await authenticationManager.signUp(email: email, password: password, name: name)
//                     dismiss()
//                 } catch {
//                     await MainActor.run {
//                         alertMessage = error.localizedDescription
//                         showAlert = true
//                     }
//                 }
//             }
//         } else {
//             Task {
//                 do {
//                     try await authenticationManager.signInWithEmail(email: email, password: password)
//                     dismiss()
//                 } catch {
//                     await MainActor.run {
//                         alertMessage = error.localizedDescription
//                         showAlert = true
//                     }
//                 }
//             }
//         }
//     }
    
//     private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
//         switch result {
//         case .success(let authorization):
//             if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
//                 Task {
//                     do {
//                         try await authenticationManager.handleAppleSignIn(credential: appleIDCredential)
//                         await MainActor.run {
//                             dismiss()
//                         }
//                     } catch {
//                         await MainActor.run {
//                             alertMessage = error.localizedDescription
//                             showAlert = true
//                         }
//                     }
//                 }
//             }
//         case .failure(let error):
//             alertMessage = error.localizedDescription
//             showAlert = true
//         }
//     }
// }

// #Preview {
//     AuthenticationView()
//         .environmentObject(AuthenticationManager.shared)
// } 