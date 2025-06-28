import SwiftUI

struct TimerView: View {
    @StateObject private var timerViewModel = TimerViewModel()
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current UV and Time to Burn Info
                    UVInfoCard()
                        .environmentObject(timerViewModel)
                        .environmentObject(weatherViewModel)
                    
                    // Timer Display
                    TimerDisplayCard()
                        .environmentObject(timerViewModel)
                    
                    // Sunscreen Reapply Timer
                    SunscreenReapplyCard()
                        .environmentObject(timerViewModel)
                    
                    // Timer Controls
                    TimerControlsCard()
                        .environmentObject(timerViewModel)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
            .navigationTitle("Sun Timer")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Update timer with current UV data
                if let currentUV = weatherViewModel.currentUVData?.uvIndex {
                    timerViewModel.updateUVIndex(currentUV)
                }
            }
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
                    Text("~\(timerViewModel.timeToBurn) min")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor)
                }
            }
            
            // Exposure Progress Bar
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
            
            Text(timerViewModel.formatTime(timerViewModel.elapsedTime))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundColor(timerViewModel.getExposureStatus().color)
                .padding(.vertical, 8)
            
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
                    Text(timerViewModel.formatTime(timerViewModel.sunscreenReapplyTime))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timerViewModel.sunscreenReapplyTime < 300 ? .red : .blue)
                    
                    if timerViewModel.sunscreenReapplyTime < 300 {
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

struct TimerControlsCard: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                if timerViewModel.isTimerRunning {
                    timerViewModel.pauseTimer()
                } else {
                    timerViewModel.startTimer()
                }
            }) {
                HStack {
                    Image(systemName: timerViewModel.isTimerRunning ? "pause.fill" : "play.fill")
                    Text(timerViewModel.isTimerRunning ? "Pause" : "Start")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(timerViewModel.isTimerRunning ? Color.orange : Color.green)
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
} 