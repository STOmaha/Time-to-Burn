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
            // Dynamic Island (keep as before for now)
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
                        Button("Apply Sunscreen") {}
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        Spacer()
                        Button("Reset") {}
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
            } compactTrailing: {
                let currentTotalExposure = context.state.totalExposureTime + context.state.elapsedTime
                Text(formatTime(currentTotalExposure))
                    .font(.caption2)
                    .fontWeight(.medium)
            } minimal: {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(getUVColor(context.attributes.uvIndex))
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