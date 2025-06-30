import ActivityKit
import WidgetKit
import SwiftUI

struct UVExposureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UVExposureAttributes.self) { context in
            // Lock screen/banner UI
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                    Text("UV Exposure")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("UV \(context.attributes.uvIndex)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(getUVColor(context.attributes.uvIndex))
                }
                
                // Progress bar
                let progress = context.state.isTimerRunning ? 
                    (context.state.elapsedTime / TimeInterval(context.attributes.maxExposureTime)) : 0.0
                
                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: getUVColor(context.attributes.uvIndex)))
                    .scaleEffect(y: 2)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exposure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(context.state.elapsedTime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(TimeInterval(context.attributes.maxExposureTime)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                // Sunscreen status
                if let lastApplication = context.state.lastSunscreenApplication {
                    let timeSinceApplication = Date().timeIntervalSince(lastApplication)
                    let timeUntilReapply = max(0, 7200 - timeSinceApplication) // 2 hours
                    
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.blue)
                        Text("Reapply in \(formatTime(timeUntilReapply))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                // Expanded UI
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
                        Text(formatTime(context.state.elapsedTime))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("of \(formatTime(TimeInterval(context.attributes.maxExposureTime)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    // Progress circle
                    let progress = context.state.isTimerRunning ? 
                        (context.state.elapsedTime / TimeInterval(context.attributes.maxExposureTime)) : 0.0
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: min(progress, 1.0))
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
                        Button("Apply Sunscreen") {
                            // This will be handled by the app
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Spacer()
                        
                        Button("Reset") {
                            // This will be handled by the app
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            } compactLeading: {
                // Compact leading
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
            } compactTrailing: {
                // Compact trailing
                Text(formatTime(context.state.elapsedTime))
                    .font(.caption2)
                    .fontWeight(.medium)
            } minimal: {
                // Minimal
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0:
            return .green
        case 1...2:
            return .green
        case 3...5:
            return .yellow
        case 6...7:
            return .orange
        case 8...10:
            return .red
        default:
            return .purple
        }
    }
} 