import WidgetKit
import SwiftUI

struct TimeToBurnWidget: Widget {
    let kind: String = "TimeToBurnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TimeToBurnWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Time to Burn")
        .description("Track your UV exposure time with real-time data")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), sharedData: createSampleData())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let sharedData = SharedDataManager.shared.loadSharedData() ?? createSampleData()
        print("Widget: getSnapshot - UV: \(sharedData.currentUVIndex), Timer Running: \(sharedData.isTimerRunning)")
        let entry = SimpleEntry(date: Date(), sharedData: sharedData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let sharedData = SharedDataManager.shared.loadSharedData() ?? createSampleData()
        print("Widget: getTimeline - UV: \(sharedData.currentUVIndex), Timer Running: \(sharedData.isTimerRunning)")
        let entry = SimpleEntry(date: currentDate, sharedData: sharedData)
        
        // Update every minute when timer is running, every 5 minutes otherwise
        let updateInterval: TimeInterval = sharedData.isTimerRunning ? 60 : 300
        let nextUpdate = currentDate.addingTimeInterval(updateInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func createSampleData() -> SharedUVData {
        return SharedUVData(
            currentUVIndex: 5,
            timeToBurn: 30,
            elapsedTime: 1200,
            totalExposureTime: 1800,
            isTimerRunning: true,
            lastSunscreenApplication: Date().addingTimeInterval(-3600),
            sunscreenReapplyTimeRemaining: 3600,
            exposureStatus: .warning,
            exposureProgress: 0.7
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let sharedData: SharedUVData
}

struct TimeToBurnWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.sharedData)
        case .systemMedium:
            MediumWidgetView(data: entry.sharedData)
        case .systemLarge:
            LargeWidgetView(data: entry.sharedData)
        default:
            SmallWidgetView(data: entry.sharedData)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let data: SharedUVData
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with UV Index
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UV \(data.currentUVIndex)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UVColorUtils.getUVColor(data.currentUVIndex))
                    
                    Text(data.exposureStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(data.exposureStatus.color)
                }
                Spacer()
                
                // UV Icon
                Image(systemName: data.currentUVIndex == 0 ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(data.currentUVIndex == 0 ? .blue : UVColorUtils.getUVColor(data.currentUVIndex))
                    .font(.title2)
            }
            
            // Progress Bar
            ProgressView(value: data.exposureProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: data.exposureStatus.color))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Timer Display
            if data.isTimerRunning {
                Text(formatTime(data.elapsedTime))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(data.exposureStatus.color)
                
                Text("Session")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text(formatTime(data.totalExposureTime))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text("Total Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    UVColorUtils.getUVColor(data.currentUVIndex).opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let data: SharedUVData
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - UV Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UV \(data.currentUVIndex)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(UVColorUtils.getUVColor(data.currentUVIndex))
                        
                        Text("~\(data.timeToBurn) min to burn")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Image(systemName: data.currentUVIndex == 0 ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(data.currentUVIndex == 0 ? .blue : UVColorUtils.getUVColor(data.currentUVIndex))
                        .font(.title)
                }
                
                // Status indicator
                HStack {
                    Text(data.exposureStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(data.exposureStatus.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(data.exposureStatus.color.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if data.isTimerRunning {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                // Progress bar
                ProgressView(value: data.exposureProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: data.exposureStatus.color))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            
            // Right side - Timer Info
            VStack(alignment: .trailing, spacing: 8) {
                if data.isTimerRunning {
                    VStack(spacing: 4) {
                        Text("Session")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatTime(data.elapsedTime))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(data.exposureStatus.color)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Total Today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatTime(data.totalExposureTime))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                // Sunscreen info
                if data.lastSunscreenApplication != nil {
                    VStack(spacing: 2) {
                        Text("Reapply")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatTime(data.sunscreenReapplyTimeRemaining))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(data.sunscreenReapplyTimeRemaining < 300 ? .red : .blue)
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    UVColorUtils.getUVColor(data.currentUVIndex).opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let data: SharedUVData
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time to Burn")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("UV Exposure Tracker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Image(systemName: data.currentUVIndex == 0 ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(data.currentUVIndex == 0 ? .blue : UVColorUtils.getUVColor(data.currentUVIndex))
                    .font(.title2)
            }
            
            // UV Index Section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current UV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.currentUVIndex)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(UVColorUtils.getUVColor(data.currentUVIndex))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Time to Burn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if data.currentUVIndex == 0 {
                        Text("∞")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    } else {
                        Text("~\(data.timeToBurn) min")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(UVColorUtils.getUVColor(data.currentUVIndex))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            
            // Progress Section
            VStack(spacing: 8) {
                HStack {
                    Text("Exposure Progress")
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(data.exposureProgress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(data.exposureStatus.color)
                }
                
                ProgressView(value: data.exposureProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: data.exposureStatus.color))
                    .scaleEffect(x: 1, y: 3, anchor: .center)
                
                Text(data.exposureStatus.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(data.exposureStatus.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(data.exposureStatus.color.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            
            // Timer Section
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(data.isTimerRunning ? "Session" : "Total Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(data.isTimerRunning ? data.elapsedTime : data.totalExposureTime))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(data.isTimerRunning ? data.exposureStatus.color : .primary)
                }
                
                Spacer()
                
                if data.lastSunscreenApplication != nil {
                    VStack(spacing: 4) {
                        Text("Reapply")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(data.sunscreenReapplyTimeRemaining))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(data.sunscreenReapplyTimeRemaining < 300 ? .red : .blue)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    UVColorUtils.getUVColor(data.currentUVIndex).opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .containerBackground(.fill, for: .widget)
    }
}

// Helper function to format time
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

#Preview(as: .systemSmall) {
    TimeToBurnWidget()
} timeline: {
    let sharedData = SharedUVData(
        currentUVIndex: 5,
        timeToBurn: 30,
        elapsedTime: 1200,
        totalExposureTime: 1800,
        isTimerRunning: true,
        lastSunscreenApplication: Date().addingTimeInterval(-3600),
        sunscreenReapplyTimeRemaining: 3600,
        exposureStatus: .warning,
        exposureProgress: 0.7
    )
    SimpleEntry(date: .now, sharedData: sharedData)
}

#Preview(as: .systemMedium) {
    TimeToBurnWidget()
} timeline: {
    let sharedData = SharedUVData(
        currentUVIndex: 8,
        timeToBurn: 20,
        elapsedTime: 600,
        totalExposureTime: 1200,
        isTimerRunning: true,
        lastSunscreenApplication: Date().addingTimeInterval(-3600),
        sunscreenReapplyTimeRemaining: 3600,
        exposureStatus: .warning,
        exposureProgress: 0.6
    )
    SimpleEntry(date: .now, sharedData: sharedData)
}

#Preview(as: .systemLarge) {
    TimeToBurnWidget()
} timeline: {
    let sharedData = SharedUVData(
        currentUVIndex: 3,
        timeToBurn: 45,
        elapsedTime: 1800,
        totalExposureTime: 3600,
        isTimerRunning: false,
        lastSunscreenApplication: Date().addingTimeInterval(-7200),
        sunscreenReapplyTimeRemaining: 0,
        exposureStatus: .exceeded,
        exposureProgress: 1.0
    )
    SimpleEntry(date: .now, sharedData: sharedData)
} 