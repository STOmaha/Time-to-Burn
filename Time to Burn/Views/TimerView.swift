import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var showingSunscreenTimer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current UV and Time to Burn Info
                    UVInfoCard()
                        .environmentObject(timerViewModel)
                        .environmentObject(weatherViewModel)
                    
                    // UV Zero Warning (when UV is 0)
                    if timerViewModel.isUVZero {
                        UVZeroWarningCard()
                    }
                    
                    // Timer Display (only show when UV > 0)
                    if !timerViewModel.isUVZero {
                        TimerDisplayCard()
                            .environmentObject(timerViewModel)
                        
                        // Sunscreen Reapply Timer
                        SunscreenReapplyCard(showingSunscreenTimer: $showingSunscreenTimer)
                            .environmentObject(timerViewModel)
                        
                        // Timer Controls
                        TimerControlsCard(showingSunscreenTimer: $showingSunscreenTimer)
                            .environmentObject(timerViewModel)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
            .navigationTitle("Sun Timer")
            .navigationBarTitleDisplayMode(.large)
            .blur(radius: showingSunscreenTimer ? 10 : 0)
            .overlay(
                Group {
                    if showingSunscreenTimer {
                        SunscreenTimerPopup(
                            isPresented: $showingSunscreenTimer,
                            timerViewModel: timerViewModel
                        )
                    }
                }
            )
        }
    }
}

struct UVInfoCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        let currentUV = weatherViewModel.currentUVData?.uvIndex ?? 0
        let uvColor = UVColorUtils.getUVColor(currentUV)
        
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current UV Index")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(currentUV)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Time to Burn")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if currentUV == 0 {
                        Text("∞")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    } else {
                        Text("~\(UVColorUtils.calculateTimeToBurnMinutes(uvIndex: currentUV)) min")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(uvColor)
                    }
                }
            }
            
            // Exposure Progress Bar (only show when UV > 0)
            if currentUV > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Exposure Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(timerViewModel.getExposureStatus().message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(timerViewModel.getExposureStatus().color)
                    }
                    
                    ProgressView(value: timerViewModel.getExposureProgress())
                        .progressViewStyle(LinearProgressViewStyle(tint: timerViewModel.getExposureStatus().color))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct UVZeroWarningCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("No UV Exposure")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text("UV Index is currently 0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("No sun protection needed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Safe to be outdoors without protection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct TimerDisplayCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Exposure Timer")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Show remaining time when timer is running, elapsed time when paused
            if timerViewModel.isTimerRunning {
                Text(timerViewModel.getRemainingTime())
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .foregroundColor(timerViewModel.getExposureStatus().color)
                    .padding(.vertical, 8)
            } else {
                Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .foregroundColor(timerViewModel.getExposureStatus().color)
                    .padding(.vertical, 8)
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.getRemainingTime())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 4) {
                    Text("Total Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.formatTime(timerViewModel.totalExposureTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct SunscreenReapplyCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @Binding var showingSunscreenTimer: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Sunscreen Reapply")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if timerViewModel.lastSunscreenApplication != nil {
                VStack(spacing: 8) {
                    Text("Time until reapply:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    let timeRemaining = timerViewModel.getSunscreenReapplyTimeRemaining()
                    Text(timerViewModel.formatTime(timeRemaining))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining < 300 ? .red : .blue)
                    
                    if timeRemaining < 300 {
                        Text("Reapply sunscreen now!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text("No sunscreen applied yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                showingSunscreenTimer = true
            }) {
                HStack {
                    Image(systemName: "drop.fill")
                    Text("Apply Sunscreen")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct TimerControlsCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @Binding var showingSunscreenTimer: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Main timer control
            HStack(spacing: 16) {
                Button(action: {
                    switch timerViewModel.currentState {
                    case .notStarted, .paused:
                        timerViewModel.startTimer()
                    case .running:
                        timerViewModel.pauseTimer()
                    case .sunscreenApplied:
                        timerViewModel.resumeTimer()
                    case .exceeded:
                        timerViewModel.resetTimer()
                    }
                }) {
                    HStack {
                        Image(systemName: getTimerButtonIcon())
                        Text(getTimerButtonText())
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(getTimerButtonColor())
                    .cornerRadius(12)
                }
                
                Button(action: {
                    timerViewModel.resetTimer()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
            
            // Sunscreen button (show when timer is running or paused)
            if timerViewModel.currentState == .running || timerViewModel.currentState == .paused {
                Button(action: {
                    showingSunscreenTimer = true
                }) {
                    HStack {
                        Image(systemName: "drop.fill")
                        Text("Apply Sunscreen")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private func getTimerButtonIcon() -> String {
        switch timerViewModel.currentState {
        case .notStarted, .paused:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .sunscreenApplied:
            return "play.fill"
        case .exceeded:
            return "arrow.clockwise"
        }
    }
    
    private func getTimerButtonText() -> String {
        switch timerViewModel.currentState {
        case .notStarted:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .sunscreenApplied:
            return "Resume"
        case .exceeded:
            return "Reset"
        }
    }
    
    private func getTimerButtonColor() -> Color {
        switch timerViewModel.currentState {
        case .notStarted, .paused, .sunscreenApplied:
            return .green
        case .running:
            return .orange
        case .exceeded:
            return .red
        }
    }
}

// MARK: - Sunscreen Timer Popup
struct SunscreenTimerPopup: View {
    @Binding var isPresented: Bool
    let timerViewModel: TimerViewModel
    @State private var showingReapplyConfirmation = false
    @State private var showingStopConfirmation = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Popup content
            VStack(spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Sunscreen Timer")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
                
                // Timer display
                VStack(spacing: 16) {
                    if let sunscreenStatus = timerViewModel.sunscreenStatus, sunscreenStatus.isActive {
                        // Active sunscreen timer
                        VStack(spacing: 8) {
                            Text("Time Remaining")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(timerViewModel.formatTime(sunscreenStatus.timeRemaining))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(sunscreenStatus.timeRemaining < 300 ? .red : .blue)
                            
                            if sunscreenStatus.timeRemaining < 300 {
                                Text("⚠️ Time to reapply!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            } else {
                                Text("Sunscreen is active")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        // No active sunscreen
                        VStack(spacing: 8) {
                            Text("No Active Sunscreen")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Apply sunscreen to start the timer")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if let sunscreenStatus = timerViewModel.sunscreenStatus, sunscreenStatus.isActive {
                        // Active sunscreen - show reapply and stop options
                        Button(action: {
                            showingReapplyConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "drop.fill")
                                Text("Reapply Sunscreen")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingStopConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Timer")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    } else {
                        // No active sunscreen - show apply option
                        Button(action: {
                            timerViewModel.applySunscreen()
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "drop.fill")
                                Text("Apply Sunscreen")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
        }
        .confirmationDialog(
            "Reapply Sunscreen?",
            isPresented: $showingReapplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reapply", role: .none) {
                timerViewModel.applySunscreen()
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will restart the 2-hour sunscreen timer.")
        }
        .confirmationDialog(
            "Stop Sunscreen Timer?",
            isPresented: $showingStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Timer", role: .destructive) {
                timerViewModel.cancelSunscreenTimer()
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will stop the sunscreen timer and resume UV exposure tracking.")
        }
    }
} 