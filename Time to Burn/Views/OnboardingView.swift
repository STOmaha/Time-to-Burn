import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var animateCard = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(onboardingManager.currentStep + 1), total: Double(onboardingManager.onboardingSteps.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // Main content
                if onboardingManager.isDataLoading {
                    loadingView
                } else {
                    cardView
                }
                
                Spacer()
                
                // Navigation buttons
                navigationButtons
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animateCard = true
            }
            
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Card View
    private var cardView: some View {
        let currentStep = onboardingManager.onboardingSteps[onboardingManager.currentStep]
        
        return VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(currentStep.iconColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: currentStep.icon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(currentStep.iconColor)
                }
                .scaleEffect(animateContent ? 1.0 : 0.8)
                .opacity(animateContent ? 1.0 : 0.0)
                
                // Content
                VStack(spacing: 16) {
                    Text(currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(currentStep.subtitle)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(currentStep.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1.0 : 0.0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            .scaleEffect(animateCard ? 1.0 : 0.9)
            .opacity(animateCard ? 1.0 : 0.0)
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                // Loading animation
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: onboardingManager.dataLoadProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: onboardingManager.dataLoadProgress)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                        .opacity(onboardingManager.dataLoadProgress >= 1.0 ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.5), value: onboardingManager.dataLoadProgress)
                }
                
                VStack(spacing: 8) {
                    Text("Setting up Time to Burn")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Loading your personalized UV data...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        let currentStep = onboardingManager.onboardingSteps[onboardingManager.currentStep]
        
        return VStack(spacing: 16) {
            // Primary action button
            Button(action: {
                Task {
                    await onboardingManager.handleStepAction()
                }
            }) {
                HStack {
                    if onboardingManager.isDataLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(currentStep.actionTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(currentStep.iconColor)
                )
                .foregroundColor(.white)
            }
            .disabled(onboardingManager.isDataLoading)
            
            // Back button (show only if not first step and not loading)
            if onboardingManager.currentStep > 0 && !onboardingManager.isDataLoading {
                Button("Back") {
                    onboardingManager.previousStep()
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview {
    OnboardingView()
} 