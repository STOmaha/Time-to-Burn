import WidgetKit
import SwiftUI

struct TimeToBurnWidget: Widget {
    let kind: String = "TimeToBurnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UVIndexProvider()) { entry in
            UVIndexWidgetView(entry: entry)
        }
        .configurationDisplayName("Current UV Index")
        .description("Shows the current UV Index from the main app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UVIndexEntry: TimelineEntry {
    let date: Date
    let uvIndex: Int?
    let timeToBurn: Int?
    let isTimerRunning: Bool?
    let exposureStatus: String?
    let debugInfo: String?
}

struct UVIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVIndexEntry {
        UVIndexEntry(date: Date(), uvIndex: nil, timeToBurn: nil, isTimerRunning: nil, exposureStatus: nil, debugInfo: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let debugInfo = sharedData != nil ? "Data loaded: UV=\(sharedData!.currentUVIndex)" : "No data found"
        
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            debugInfo: debugInfo
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let debugInfo = sharedData != nil ? "Timeline: UV=\(sharedData!.currentUVIndex)" : "Timeline: No data"
        
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            debugInfo: debugInfo
        )
        
        // Refresh every 30 seconds for debugging
        let nextUpdate = Date().addingTimeInterval(30)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct UVIndexWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        VStack(spacing: 4) {
            Text("UV Index")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
            
            if let timeToBurn = entry.timeToBurn, timeToBurn > 0 {
                Text("\(timeToBurn) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let status = entry.exposureStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Debug info in small font
            if let debug = entry.debugInfo {
                Text(debug)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview(as: .systemSmall) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, isTimerRunning: true, exposureStatus: "Safe", debugInfo: "Preview data")
} 