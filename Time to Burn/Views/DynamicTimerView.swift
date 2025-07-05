import SwiftUI
import Charts

struct DynamicTimerView: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var showingUVChart = false
    @State private var showingSunscreenTimer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current UV and Time to Burn Info
                    UVInfoCard()
                        .environmentObject(timerViewModel)
                        .environmentObject(weatherViewModel)
                    
                    // UV Change Notification
                    if let notification = timerViewModel.uvChangeNotification {
                        UVChangeNotificationCard(message: notification)
                    }
                    
                    // Dynamic content based on timer state
                    if timerViewModel.isUVZero {
                        UVZeroWarningCard()
                    } else if timerViewModel.currentState == .running || timerViewModel.currentState == .paused || timerViewModel.currentState == .sunscreenApplied {
                        ActiveTimerContent(showingSunscreenTimer: $showingSunscreenTimer)
                    } else {
                        InactiveTimerContent()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
            .navigationTitle("Sun Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingUVChart.toggle()
                    }) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        timerViewModel.testWidgetData()
                    }) {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingUVChart) {
                UVExposureChartView()
                    .environmentObject(weatherViewModel)
                    .environmentObject(timerViewModel)
            }
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

struct ActiveTimerContent: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @Binding var showingSunscreenTimer: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer Display
            TimerDisplayCard()
                .environmentObject(timerViewModel)
            
            // Exposure Progress with UV Graph
            ExposureProgressCard()
                .environmentObject(timerViewModel)
            
            // Sunscreen Reapply Timer
            SunscreenReapplyCard(showingSunscreenTimer: $showingSunscreenTimer)
                .environmentObject(timerViewModel)
            
            // Timer Controls
            TimerControlsCard(showingSunscreenTimer: $showingSunscreenTimer)
                .environmentObject(timerViewModel)
            
            // Exposure Warnings
            ExposureWarningsCard()
                .environmentObject(timerViewModel)
        }
    }
}

struct InactiveTimerContent: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Today's Summary
            TodaySummaryCard()
                .environmentObject(timerViewModel)
            
            // Quick Start Button
            QuickStartCard()
                .environmentObject(timerViewModel)
            
            // Sunscreen Status
            SunscreenStatusCard()
                .environmentObject(timerViewModel)
        }
    }
}

struct ExposureProgressCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Exposure Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text(timerViewModel.getExposureStatus().message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(timerViewModel.getExposureStatus().color)
            }
            
            // Progress bar
            ProgressView(value: timerViewModel.getExposureProgress())
                .progressViewStyle(LinearProgressViewStyle(tint: timerViewModel.getExposureStatus().color))
                .scaleEffect(x: 1, y: 3, anchor: .center)
            
            // Progress details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(timerViewModel.getExposureProgress() * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(timerViewModel.getExposureStatus().color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Max Safe Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(UVColorUtils.calculateTimeToBurnMinutes(uvIndex: timerViewModel.currentUVIndex)) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
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

struct TodaySummaryCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Today's Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Total Exposure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.formatTime(timerViewModel.totalExposureTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerViewModel.getExposureStatus().message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(timerViewModel.getExposureStatus().color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(timerViewModel.getExposureStatus().color.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            // Progress indicator
            if timerViewModel.totalExposureTime > 0 {
                ProgressView(value: timerViewModel.getExposureProgress())
                    .progressViewStyle(LinearProgressViewStyle(tint: timerViewModel.getExposureStatus().color))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
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

struct QuickStartCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Quick Start")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("Start tracking your UV exposure now")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                timerViewModel.startTimer()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Timer")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
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

struct SunscreenStatusCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Sunscreen Status")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if let lastApplication = timerViewModel.lastSunscreenApplication {
                VStack(spacing: 8) {
                    Text("Last applied: \(lastApplication, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    let timeRemaining = timerViewModel.getSunscreenReapplyTimeRemaining()
                    if timeRemaining > 0 {
                        Text("Reapply in: \(timerViewModel.formatTime(timeRemaining))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(timeRemaining < 300 ? .red : .blue)
                    } else {
                        Text("Time to reapply!")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text("No sunscreen applied today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                timerViewModel.applySunscreen()
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

struct ExposureWarningsCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        let totalExposure = timerViewModel.totalExposureTime + timerViewModel.elapsedTime
        let maxExposure = TimeInterval(timerViewModel.timeToBurn)
        let progress = totalExposure / maxExposure
        
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Exposure Warnings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if progress >= 1.0 {
                WarningRow(
                    icon: "xmark.circle.fill",
                    color: .red,
                    title: "Exposure Limit Exceeded",
                    message: "You've exceeded the safe exposure time. Seek shade immediately."
                )
            } else if progress >= 0.8 {
                WarningRow(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "Approaching Limit",
                    message: "You're approaching the safe exposure limit. Consider seeking shade soon."
                )
            } else {
                Text("Exposure is within safe limits")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
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

struct WarningRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UVChangeNotificationCard: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    DynamicTimerView()
        .environmentObject(TimerViewModel())
        .environmentObject(WeatherViewModel(locationManager: LocationManager()))
} 