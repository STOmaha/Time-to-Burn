// import SwiftUI

// struct TimerView: View {
//     @EnvironmentObject private var timerViewModel: TimerViewModel
//     @EnvironmentObject private var weatherViewModel: WeatherViewModel

    
//     var body: some View {
//         NavigationView {
//             ScrollView {
//                 VStack(spacing: 24) {
//                     // Current UV and Time to Burn Info
//                     UVInfoCard()
//                         .environmentObject(timerViewModel)
//                         .environmentObject(weatherViewModel)
                    
//                     // UV Zero Warning (when UV is 0)
//                     if timerViewModel.isUVZero {
//                         UVZeroWarningCard()
//                     }
                    
//                     // Timer Display (only show when UV > 0)
//                     if !timerViewModel.isUVZero {
//                         TimerDisplayCard()
//                             .environmentObject(timerViewModel)
                        
//                         // Sunscreen Reapply Timer
//                                     SunscreenReapplyCard()
//                 .environmentObject(timerViewModel)
                        
//                         // Timer Controls
//                                     TimerControlsCard()
//                 .environmentObject(timerViewModel)
                    

//                     }
//                 }
//                 .padding(.horizontal)
//                 .padding(.top, 24)
//             }
//             .navigationTitle("Sun Timer")
//             .navigationBarTitleDisplayMode(.large)
//         }
//     }
// }

// struct UVInfoCard: View {
//     @EnvironmentObject private var timerViewModel: TimerViewModel
//     @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
//     var body: some View {
//         let currentUV = weatherViewModel.currentUVData?.uvIndex ?? 0
//         let uvColor = UVColorUtils.getUVColor(currentUV)
        
//         VStack(spacing: 16) {
//             HStack {
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text("Current UV Index")
//                         .font(.headline)
//                         .foregroundColor(.primary)
//                     Text("\(currentUV)")
//                         .font(.system(size: 48, weight: .bold, design: .rounded))
//                         .foregroundColor(uvColor)
//                 }
//                 Spacer()
//                 VStack(alignment: .trailing, spacing: 4) {
//                     Text("Time to Burn")
//                         .font(.headline)
//                         .foregroundColor(.primary)
//                     if currentUV == 0 {
//                         Text("∞")
//                             .font(.system(size: 32, weight: .bold, design: .rounded))
//                             .foregroundColor(.green)
//                     } else {
//                         Text("~\(UnitConverter.shared.formatTimeToBurn(currentUV))")
//                             .font(.system(size: 32, weight: .bold, design: .rounded))
//                             .foregroundColor(uvColor)
//                     }
//                 }
//             }
            
//             // Exposure Progress Bar (only show when UV > 0)
//             if currentUV > 0 {
//                 VStack(alignment: .leading, spacing: 8) {
//                     HStack {
//                         Text("Exposure Progress")
//                             .font(.subheadline)
//                             .fontWeight(.medium)
//                             .foregroundColor(.primary)
//                         Spacer()
//                         Text(timerViewModel.getExposureStatus().message)
//                             .font(.subheadline)
//                             .fontWeight(.medium)
//                             .foregroundColor(timerViewModel.getExposureStatus().color)
//                     }
                    
//                     ProgressView(value: timerViewModel.getExposureProgress())
//                         .progressViewStyle(LinearProgressViewStyle(tint: timerViewModel.getExposureStatus().color))
//                         .scaleEffect(x: 1, y: 2, anchor: .center)
//                 }
//             }
//         }
//         .padding(20)
//         .background(
//             RoundedRectangle(cornerRadius: 16, style: .continuous)
//                 .fill(Color(.systemBackground).opacity(0.95))
//                 .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
//         )
//     }
// }

// struct UVZeroWarningCard: View {
//     var body: some View {
//         VStack(spacing: 16) {
//             HStack {
//                 Image(systemName: "sun.max.fill")
//                     .foregroundColor(.green)
//                     .font(.title2)
//                 Text("UV Index is Zero")
//                     .font(.title2)
//                     .fontWeight(.bold)
//                     .foregroundColor(.primary)
//                 Spacer()
//             }
            
//             Text("The UV index is currently 0, which means there's no risk of sunburn. You can safely spend time outdoors without sun protection.")
//                 .font(.body)
//                 .foregroundColor(.secondary)
//                 .multilineTextAlignment(.leading)
//         }
//         .padding(20)
//         .background(
//             RoundedRectangle(cornerRadius: 16, style: .continuous)
//                 .fill(Color.green.opacity(0.1))
//                 .overlay(
//                     RoundedRectangle(cornerRadius: 16, style: .continuous)
//                         .stroke(Color.green.opacity(0.3), lineWidth: 1)
//                 )
//         )
//     }
// }

// struct TimerDisplayCard: View {
//     @EnvironmentObject private var timerViewModel: TimerViewModel
    
//     var body: some View {
//         VStack(spacing: 16) {
//             HStack {
//                 Image(systemName: "timer")
//                     .foregroundColor(.blue)
//                     .font(.title2)
//                 Text("Timer")
//                     .font(.title2)
//                     .fontWeight(.bold)
//                     .foregroundColor(.primary)
//                 Spacer()
//             }
            
//             if timerViewModel.isRunning {
//                 VStack(spacing: 8) {
//                     Text("Time Remaining")
//                         .font(.headline)
//                         .foregroundColor(.secondary)
                    
//                     Text(timerViewModel.formattedTimeRemaining)
//                         .font(.system(size: 48, weight: .bold, design: .monospaced))
//                         .foregroundColor(timerViewModel.timeRemainingColor)
//                 }
                
//                 // Progress ring
//                 ZStack {
//                     Circle()
//                         .stroke(Color.gray.opacity(0.3), lineWidth: 8)
//                     Circle()
//                         .trim(from: 0, to: timerViewModel.progress)
//                         .stroke(timerViewModel.timeRemainingColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
//                         .rotationEffect(.degrees(-90))
//                         .animation(.linear(duration: 1), value: timerViewModel.progress)
//                 }
//                 .frame(width: 120, height: 120)
//             } else {
//                 VStack(spacing: 8) {
//                     Text("Safe Exposure Time")
//                         .font(.headline)
//                         .foregroundColor(.secondary)
                    
//                     Text(timerViewModel.formattedSafeTime)
//                         .font(.system(size: 48, weight: .bold, design: .monospaced))
//                         .foregroundColor(.primary)
//                 }
//             }
//         }
//         .padding(20)
//         .background(
//             RoundedRectangle(cornerRadius: 16, style: .continuous)
//                 .fill(Color(.systemBackground).opacity(0.95))
//                 .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
//         )
//     }
// }

// struct SunscreenReapplyCard: View {
//     @EnvironmentObject private var timerViewModel: TimerViewModel
    
//     var body: some View {
//         VStack(spacing: 16) {
//             HStack {
//                 Image(systemName: "drop.fill")
//                     .foregroundColor(.blue)
//                     .font(.title2)
//                 Text("Sunscreen Status")
//                     .font(.title2)
//                     .fontWeight(.bold)
//                     .foregroundColor(.primary)
//                 Spacer()
//             }
            
//             if let lastApplication = timerViewModel.lastSunscreenApplication {
//                 VStack(spacing: 8) {
//                     Text("Last applied: \(lastApplication, style: .relative) ago")
//                         .font(.subheadline)
//                         .foregroundColor(.secondary)
                    
//                     let timeRemaining = timerViewModel.getSunscreenReapplyTimeRemaining()
//                     if timeRemaining > 300 {
//                         Text("Reapply in: \(timerViewModel.formatTime(timeRemaining))")
//                             .font(.title3)
//                             .fontWeight(.bold)
//                             .foregroundColor(.blue)
//                     } else if timeRemaining > 0 {
//                         Text("Reapply in: \(timerViewModel.formatTime(timeRemaining))")
//                             .font(.title3)
//                             .fontWeight(.bold)
//                             .foregroundColor(.red)
//                     } else {
//                         Text("Time to reapply!")
//                             .font(.title3)
//                             .fontWeight(.bold)
//                             .foregroundColor(.red)
//                     }
//                 }
//             } else {
//                 Text("No sunscreen applied today")
//                     .font(.subheadline)
//                     .foregroundColor(.secondary)
//             }
            
//             Button(action: {
//                 timerViewModel.applySunscreen()
//             }) {
//                 HStack {
//                     Image(systemName: "drop.fill")
//                     Text("Apply Sunscreen")
//                 }
//                 .font(.headline)
//                 .foregroundColor(.white)
//                 .padding()
//                 .frame(maxWidth: .infinity)
//                 .background(Color.blue)
//                 .cornerRadius(12)
//             }
//         }
//         .padding(20)
//         .background(
//             RoundedRectangle(cornerRadius: 16, style: .continuous)
//                 .fill(Color(.systemBackground).opacity(0.95))
//                 .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
//         )
//     }
// }

// struct TimerControlsCard: View {
//     @EnvironmentObject private var timerViewModel: TimerViewModel
    
//     var body: some View {
//         VStack(spacing: 16) {
//             HStack(spacing: 16) {
//                 Button(action: {
//                     switch timerViewModel.currentState {
//                     case .notStarted, .paused:
//                         timerViewModel.startTimer()
//                     case .running:
//                         timerViewModel.pauseTimer()
//                     case .sunscreenApplied:
//                         timerViewModel.resumeTimer()
//                     case .exceeded:
//                         timerViewModel.resetTimer()
//                     }
//                 }) {
//                     HStack {
//                         Image(systemName: getTimerButtonIcon())
//                         Text(getTimerButtonText())
//                     }
//                     .font(.headline)
//                     .foregroundColor(.white)
//                     .padding()
//                     .frame(maxWidth: .infinity)
//                     .background(getTimerButtonColor())
//                     .cornerRadius(12)
//                 }
                
//                 Button(action: {
//                     timerViewModel.resetTimer()
//                 }) {
//                     HStack {
//                         Image(systemName: "arrow.clockwise")
//                         Text("Reset")
//                     }
//                     .font(.headline)
//                     .foregroundColor(.white)
//                     .padding()
//                     .frame(maxWidth: .infinity)
//                     .background(Color.red)
//                     .cornerRadius(12)
//                 }
//             }
            
//             // Sunscreen button (show when timer is running or paused)
//             if timerViewModel.currentState == .running || timerViewModel.currentState == .paused {
//                 Button(action: {
//                     timerViewModel.applySunscreen()
//                 }) {
//                     HStack {
//                         Image(systemName: "drop.fill")
//                         Text("Apply Sunscreen")
//                     }
//                     .font(.headline)
//                     .foregroundColor(.white)
//                     .padding()
//                     .frame(maxWidth: .infinity)
//                     .background(Color.blue)
//                     .cornerRadius(12)
//                 }
//             }
//         }
//         .padding(20)
//         .background(
//             RoundedRectangle(cornerRadius: 16, style: .continuous)
//                 .fill(Color(.systemBackground).opacity(0.95))
//                 .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
//         )
//     }
    
//     private func getTimerButtonIcon() -> String {
//         switch timerViewModel.currentState {
//         case .notStarted, .paused:
//             return "play.fill"
//         case .running:
//             return "pause.fill"
//         case .sunscreenApplied:
//             return "play.fill"
//         case .exceeded:
//             return "arrow.clockwise"
//         }
//     }
    
//     private func getTimerButtonText() -> String {
//         switch timerViewModel.currentState {
//         case .notStarted:
//             return "Start"
//         case .running:
//             return "Pause"
//         case .paused:
//             return "Resume"
//         case .sunscreenApplied:
//             return "Resume"
//         case .exceeded:
//             return "Reset"
//         }
//     }
    
//     private func getTimerButtonColor() -> Color {
//         switch timerViewModel.currentState {
//         case .notStarted, .paused, .sunscreenApplied:
//             return .green
//         case .running:
//             return .orange
//         case .exceeded:
//             return .red
//         }
//     }
// }

// #Preview {
//     TimerView()
//         .environmentObject(TimerViewModel())
//         .environmentObject(WeatherViewModel(locationManager: LocationManager.shared))
// }





 