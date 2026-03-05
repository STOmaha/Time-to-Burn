import SwiftUI
import AuthenticationServices
import WidgetKit

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager

    var body: some View {
        ZStack {
            // Dynamic gradient background based on step
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: onboardingManager.currentStep)

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $onboardingManager.currentStep) {
                    WelcomeStep()
                        .tag(0)

                    LocationStep()
                        .tag(1)

                    NotificationStep()
                        .tag(2)

                    SignInStep(onboardingManager: onboardingManager, authenticationManager: authenticationManager)
                        .tag(3)

                    WidgetStep()
                        .tag(4)

                    SubscriptionStep(onboardingManager: onboardingManager, subscriptionManager: subscriptionManager)
                        .tag(5)

                    ReadyStep()
                        .tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: onboardingManager.currentStep)

                // Page indicator and button
                bottomSection
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let colors: [Color] = {
            switch onboardingManager.currentStep {
            case 0:
                return [Color.orange.opacity(0.15), Color.yellow.opacity(0.08)]
            case 1:
                return [Color.blue.opacity(0.12), Color.cyan.opacity(0.06)]
            case 2:
                return [Color.green.opacity(0.12), Color.mint.opacity(0.06)]
            case 3:
                return [Color.gray.opacity(0.12), Color.black.opacity(0.06)]
            case 4:
                return [Color.cyan.opacity(0.12), Color.teal.opacity(0.06)]
            case 5:
                return [Color.purple.opacity(0.12), Color.indigo.opacity(0.06)]
            case 6:
                return [Color.orange.opacity(0.18), Color.red.opacity(0.08)]
            default:
                return [Color.orange.opacity(0.15), Color.yellow.opacity(0.08)]
            }
        }()

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<onboardingManager.totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == onboardingManager.currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: index == onboardingManager.currentStep ? 10 : 8,
                               height: index == onboardingManager.currentStep ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: onboardingManager.currentStep)
                }
            }

            // Primary action button (hidden on sign in, widget, and subscription steps)
            if onboardingManager.currentStep != 3 && onboardingManager.currentStep != 4 && onboardingManager.currentStep != 5 {
                primaryButton
            }

            // Skip option for notification step
            if onboardingManager.currentStep == 2 && !onboardingManager.isNotificationAuthorized {
                Button {
                    onboardingManager.nextStep()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private var primaryButton: some View {
        let step = onboardingManager.currentStep

        Button {
            handlePrimaryAction()
        } label: {
            HStack(spacing: 8) {
                if onboardingManager.isRequestingPermission {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)

                    if step < 3 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(primaryButtonColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(onboardingManager.isRequestingPermission || !canProceed)
        .opacity(canProceed ? 1.0 : 0.6)
    }

    private var primaryButtonTitle: String {
        switch onboardingManager.currentStep {
        case 0: return "Get Started"
        case 1: return onboardingManager.isLocationAuthorized ? "Continue" : "Allow Location"
        case 2: return onboardingManager.isNotificationAuthorized ? "Continue" : "Enable Notifications"
        case 3: return "" // Sign in step uses its own button
        case 4: return "" // Widget step uses its own buttons
        case 5: return "" // Subscription step uses its own buttons
        case 6: return "Start Using App"
        default: return "Continue"
        }
    }

    private var primaryButtonColor: Color {
        switch onboardingManager.currentStep {
        case 0: return .orange
        case 1: return .blue
        case 2: return .green
        case 3: return .black
        case 4: return .cyan
        case 5: return .purple
        case 6: return .orange
        default: return .orange
        }
    }

    private var canProceed: Bool {
        switch onboardingManager.currentStep {
        case 1:
            // Location step - must have permission to proceed
            return onboardingManager.isLocationAuthorized || !onboardingManager.isRequestingPermission
        case 3:
            // Sign in step - handled by its own button
            return false
        case 4:
            // Widget step - handled by its own buttons
            return false
        case 5:
            // Subscription step - handled by its own buttons
            return false
        default:
            return true
        }
    }

    private func handlePrimaryAction() {
        switch onboardingManager.currentStep {
        case 0:
            onboardingManager.nextStep()

        case 1:
            // Location step
            if onboardingManager.isLocationAuthorized {
                onboardingManager.nextStep()
            } else {
                Task {
                    let granted = await onboardingManager.requestLocationPermission()
                    if granted {
                        onboardingManager.nextStep()
                    }
                }
            }

        case 2:
            // Notification step - request then proceed regardless
            if onboardingManager.isNotificationAuthorized {
                onboardingManager.nextStep()
            } else {
                Task {
                    _ = await onboardingManager.requestNotificationPermission()
                    onboardingManager.nextStep()
                }
            }

        case 3:
            // Sign in step - handled by SignInStep view
            break

        case 4:
            // Widget step - handled by WidgetStep view
            break

        case 5:
            // Subscription step - handled by SubscriptionStep view
            break

        case 6:
            // Ready step - complete onboarding
            onboardingManager.completeOnboarding()

        default:
            onboardingManager.nextStep()
        }
    }
}

// MARK: - Welcome Step

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon / sun illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange, .orange.opacity(0.6)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 16) {
                Text("Time to Burn")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)

                Text("Your personal UV protection companion")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Feature highlights
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    iconColor: .orange,
                    title: "Real-Time UV Index",
                    description: "Know when it's safe to be outside"
                )

                OnboardingFeatureRow(
                    icon: "timer",
                    iconColor: .blue,
                    title: "Smart Timer",
                    description: "Track sun exposure for your skin type"
                )

                OnboardingFeatureRow(
                    icon: "bell.badge",
                    iconColor: .green,
                    title: "Timely Alerts",
                    description: "Get notified when to reapply sunscreen"
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Location Step

private struct LocationStep: View {
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Location illustration
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 100, height: 100)

                Image(systemName: "location.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 16) {
                Text("Enable Location")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("We need your location to provide accurate UV index data for your area.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // Permission status indicator
            if onboardingManager.isLocationAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Location access granted")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                Text("Your location is only used for UV data and never shared.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Notification Step

private struct NotificationStep: View {
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Notification illustration
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 100, height: 100)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 16) {
                Text("Stay Protected")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Get timely alerts about UV levels, sunscreen reminders, and exposure warnings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // What you'll get
            VStack(spacing: 16) {
                OnboardingNotificationRow(
                    icon: "sun.max.fill",
                    text: "High UV alerts when protection is needed"
                )
                OnboardingNotificationRow(
                    icon: "drop.fill",
                    text: "Sunscreen reapplication reminders"
                )
                OnboardingNotificationRow(
                    icon: "clock.badge.exclamationmark",
                    text: "Exposure limit warnings"
                )
            }
            .padding(.top, 8)

            // Permission status
            if onboardingManager.isNotificationAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Notifications enabled")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Sign In Step

private struct SignInStep: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var authenticationManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Sign in illustration
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 16) {
                Text("Sign In")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Sign in with Apple to sync your data across devices and keep your settings safe.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // Benefits
            VStack(spacing: 16) {
                OnboardingNotificationRow(
                    icon: "icloud.fill",
                    text: "Sync settings across all your devices"
                )
                OnboardingNotificationRow(
                    icon: "arrow.clockwise.icloud.fill",
                    text: "Restore data if you reinstall"
                )
                OnboardingNotificationRow(
                    icon: "lock.shield.fill",
                    text: "Private and secure with Apple"
                )
            }
            .padding(.top, 8)

            // Sign in with Apple button
            if authenticationManager.isAuthenticated {
                // Already signed in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Signed in successfully")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())

                Button {
                    onboardingManager.nextStep()
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
            } else {
                // Show Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        onboardingManager.setSigningIn(true)
                        Task {
                            do {
                                try await authenticationManager.signInWithApple(authorization: authorization)
                                onboardingManager.signInCompleted()
                            } catch {
                                onboardingManager.signInFailed(error)
                            }
                            onboardingManager.setSigningIn(false)
                        }
                    case .failure(let error):
                        onboardingManager.signInFailed(error)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
                .disabled(onboardingManager.isSigningIn)

                if onboardingManager.isSigningIn {
                    ProgressView()
                        .padding(.top, 8)
                }

                if let error = onboardingManager.signInError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Subscription Step

private struct SubscriptionStep: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var subscriptionManager: SubscriptionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Premium illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "crown.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("Unlock Premium")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Get the most out of Time to Burn with premium features.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // Premium features
            VStack(spacing: 12) {
                PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced UV forecasting")
                PremiumFeatureRow(icon: "bell.badge.fill", text: "Smart notification scheduling")
                PremiumFeatureRow(icon: "icloud.fill", text: "Cross-device sync")
                PremiumFeatureRow(icon: "person.3.fill", text: "Family sharing (Annual)")
            }
            .padding(.top, 8)

            Spacer()

            // Subscription options
            VStack(spacing: 12) {
                // Annual plan (recommended)
                SubscriptionPlanButton(
                    plan: .annualFamily,
                    isSelected: subscriptionManager.selectedPlan == .annualFamily,
                    isLoading: subscriptionManager.isPurchasing && subscriptionManager.selectedPlan == .annualFamily
                ) {
                    Task {
                        let success = await subscriptionManager.purchase(plan: .annualFamily)
                        if success {
                            onboardingManager.nextStep()
                        }
                    }
                }

                // Monthly plan
                SubscriptionPlanButton(
                    plan: .monthly,
                    isSelected: subscriptionManager.selectedPlan == .monthly,
                    isLoading: subscriptionManager.isPurchasing && subscriptionManager.selectedPlan == .monthly
                ) {
                    Task {
                        let success = await subscriptionManager.purchase(plan: .monthly)
                        if success {
                            onboardingManager.nextStep()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // Error message
            if let error = subscriptionManager.purchaseError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Success message
            if subscriptionManager.showPurchaseSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Purchase successful!")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            }

            // Skip option
            Button {
                onboardingManager.nextStep()
            } label: {
                Text("Continue with free version")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .disabled(subscriptionManager.isPurchasing)

            // Terms
            Text("Subscriptions auto-renew. Cancel anytime.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Subscription Plan Button

private struct SubscriptionPlanButton: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Plan icon
                    Image(systemName: plan.icon)
                        .font(.system(size: 24))
                        .foregroundColor(plan == .annualFamily ? .purple : .blue)
                        .frame(width: 40)

                    // Plan name
                    Text(plan.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Savings badge
                    if let savings = plan.savings {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Price or loading
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text(plan.priceString)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }

                // Description on its own line with full width
                Text(plan.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 40)  // Align with text after icon
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: plan == .annualFamily ? .purple.opacity(0.3) : .clear, radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(plan == .annualFamily ? Color.purple : Color.gray.opacity(0.3), lineWidth: plan == .annualFamily ? 2 : 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - Premium Feature Row

private struct PremiumFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purple)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
        }
    }
}

// MARK: - Widget Step

private struct WidgetStep: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showingInstructions = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Widget preview illustration
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 160, height: 160)

                // Mock widget preview
                VStack(spacing: 4) {
                    Text("5")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("High")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Time to Burn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("25 min")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }

            VStack(spacing: 12) {
                Text("Stay Updated at a Glance")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Add a widget to your Home Screen for instant UV updates without opening the app.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // Widget benefits
            VStack(spacing: 12) {
                WidgetFeatureRow(icon: "eye", text: "See UV index instantly")
                WidgetFeatureRow(icon: "clock", text: "Real-time burn countdown")
                WidgetFeatureRow(icon: "location.fill", text: "Updates for your location")
            }
            .padding(.top, 8)

            Spacer()

            // Add Widget button
            Button {
                showingInstructions = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.app")
                    Text("Add Widget")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.cyan)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)

            // Skip option
            Button {
                onboardingManager.nextStep()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
        .alert("Add Widget", isPresented: $showingInstructions) {
            Button("Got it!") {
                // Reload widget timelines to ensure fresh data
                WidgetCenter.shared.reloadAllTimelines()
                onboardingManager.nextStep()
            }
        } message: {
            Text("To add the widget:\n\n1. Go to your Home Screen\n2. Long press on empty space\n3. Tap the + button\n4. Search for \"Time to Burn\"\n5. Choose your widget size")
        }
    }
}

private struct WidgetFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Ready Step

private struct ReadyStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange, .red.opacity(0.7)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "checkmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Time to Burn is ready to help you stay safe in the sun.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            // Summary
            VStack(spacing: 12) {
                OnboardingSummaryRow(icon: "sun.max.fill", text: "Real-time UV monitoring", color: .orange)
                OnboardingSummaryRow(icon: "location.fill", text: "Location-based data", color: .blue)
                OnboardingSummaryRow(icon: "bell.fill", text: "Smart notifications", color: .green)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Supporting Views

private struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct OnboardingNotificationRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

private struct OnboardingSummaryRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(LocationManager.shared)
        .environmentObject(AuthenticationManager.shared)
}
