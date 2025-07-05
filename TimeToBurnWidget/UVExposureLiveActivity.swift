import ActivityKit
import WidgetKit
import SwiftUI

struct UVExposureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UVExposureAttributes.self) { context in
            // Lock screen/banner UI
            let currentTotalExposure = context.state.totalExposureTime + context.state.elapsedTime
            let maxExposure = TimeInterval(context.attributes.maxExposureTime)
            let progress = min(currentTotalExposure / maxExposure, 1.0)
            let status = getExposureStatus(progress: progress)
            let statusColor = getStatusColor(status: status)
            let progressPercent = Int(progress * 100)

            VStack(alignment: .leading, spacing: 12) {
                // Main exposure progress
                HStack {
                    Text("Exposure Progress")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(status)
                        .font(.headline)
                        .foregroundColor(statusColor)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                // Sunscreen timer section (when active)
                if context.state.isSunscreenActive {
                    SunscreenTimerSection(context: context)
                }
                
                // Sunscreen prompt section (when needed)
                if context.state.shouldShowSunscreenPrompt {
                    SunscreenPromptSection(context: context)
                }
                
                // Main timer info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(context.state.elapsedTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(progressPercent)%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Max Safe Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatMinutes(maxExposure))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UV \(context.attributes.uvIndex)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(getUVColor(context.attributes.uvIndex))
                        Text("Exposure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        let currentTotalExposure = context.state.totalExposureTime + context.state.elapsedTime
                        Text(formatTime(currentTotalExposure))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("of \(formatTime(TimeInterval(context.attributes.maxExposureTime)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    let currentTotalExposure = context.state.totalExposureTime + context.state.elapsedTime
                    let progress = min(currentTotalExposure / TimeInterval(context.attributes.maxExposureTime), 1.0)
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(getUVColor(context.attributes.uvIndex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(getUVColor(context.attributes.uvIndex))
                            .font(.title3)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.state.isSunscreenActive {
                            // Show sunscreen timer
                            VStack(spacing: 4) {
                                Text("Sunscreen Active")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(formatTime(context.state.sunscreenTimerRemaining))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        } else if context.state.shouldShowSunscreenPrompt {
                            // Show sunscreen prompt
                            Button("Apply Sunscreen") {
                                // This will be handled by the app
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .widgetURL(URL(string: "timetoburn://apply-sunscreen"))
                        } else {
                            // Show regular controls
                            Button("Apply Sunscreen") {
                                // This will be handled by the app
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .widgetURL(URL(string: "timetoburn://apply-sunscreen"))
                        }
                        Spacer()
                        Button("Open Timer") {
                            // This will be handled by the app
                        }
                            .buttonStyle(.bordered)
                        .tint(.orange)
                        .widgetURL(URL(string: "timetoburn://open-timer"))
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
            } compactTrailing: {
                if context.state.isSunscreenActive {
                    // Show sunscreen icon when active
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                } else {
                let currentTotalExposure = context.state.totalExposureTime + context.state.elapsedTime
                Text(formatTime(currentTotalExposure))
                    .font(.caption2)
                    .fontWeight(.medium)
                }
            } minimal: {
                if context.state.isSunscreenActive {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                } else {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatMinutes(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes) min"
    }
    
    private func getExposureStatus(progress: Double) -> String {
        if progress >= 1.0 {
            return "Exceeded"
        } else if progress >= 0.8 {
            return "Warning"
        } else {
            return "Safe"
        }
    }
    
    private func getStatusColor(status: String) -> Color {
        switch status {
        case "Safe": return .green
        case "Warning": return .orange
        case "Exceeded": return .red
        default: return .gray
        }
    }
    
    private func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0: return .green
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
}

// MARK: - Sunscreen Timer Section
struct SunscreenTimerSection: View {
    let context: ActivityViewContext<UVExposureAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Sunscreen Timer")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(context.state.sunscreenTimerRemaining))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Reapply In")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(context.state.sunscreenTimerRemaining))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(context.state.sunscreenTimerRemaining < 300 ? .red : .blue)
                }
            }
            
            if context.state.sunscreenTimerRemaining < 300 {
                Text("⚠️ Time to reapply sunscreen!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Sunscreen Prompt Section
struct SunscreenPromptSection: View {
    let context: ActivityViewContext<UVExposureAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Sunscreen Recommended")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            Text("You've reached 50% of your safe exposure time. Consider applying sunscreen for continued protection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            HStack {
                Button("Apply Sunscreen") {
                    // This will be handled by the app
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .widgetURL(URL(string: "timetoburn://apply-sunscreen"))
                
                Spacer()
                
                Button("Open Timer") {
                    // This will be handled by the app
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .widgetURL(URL(string: "timetoburn://open-timer"))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
} 