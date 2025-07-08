import WidgetKit
import SwiftUI

struct TimeToBurnWidget: Widget {
    let kind: String = "TimeToBurnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UVIndexProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Current UV Index")
        .description("Shows the current UV Index from the main app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
            // Uncomment the following lines if your Xcode and SDK support iOS 17+ WidgetFamily members:
            // .content,
            // .contentAndPrivacy
        ])
    }
}

struct UVIndexEntry: TimelineEntry {
    let date: Date
    let uvIndex: Int?
    let timeToBurn: Int?
    let isTimerRunning: Bool?
    let exposureStatus: String?
    let locationName: String?
    let lastUpdated: Date?
    let debugInfo: String?
}

struct UVIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVIndexEntry {
        return UVIndexEntry(date: Date(), uvIndex: nil, timeToBurn: nil, isTimerRunning: nil, exposureStatus: nil, locationName: nil, lastUpdated: nil, debugInfo: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            locationName: sharedData?.locationName,
            lastUpdated: sharedData?.lastUpdated,
            debugInfo: sharedData != nil ? "Snapshot: UV=\(sharedData!.currentUVIndex)" : "Snapshot: No data"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        print("🌞 [Widget] ⏰ Timeline requested")
        
        let sharedData = SharedDataManager.shared.loadSharedData()
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            locationName: sharedData?.locationName,
            lastUpdated: sharedData?.lastUpdated,
            debugInfo: sharedData != nil ? "Timeline: UV=\(sharedData!.currentUVIndex)" : "Timeline: No data"
        )
        
        if let data = sharedData {
            let uvEmoji = getUVEmoji(data.currentUVIndex)
            let timeToBurnText = data.timeToBurn == Int.max ? "∞" : "\(data.timeToBurn / 60)min"
            print("🌞 [Widget] 📊 Timeline Entry Created:")
            print("   📊 UV Index: \(uvEmoji) \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(data.locationName)")
            print("   ──────────────────────────────────────")
        }
        
        // Refresh every 2 minutes
        let nextUpdate = Date().addingTimeInterval(120)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Helper Methods for Beautiful Logging
    
    private func getUVEmoji(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0: return "🌙"
        case 1...2: return "🌤️"
        case 3...5: return "☀️"
        case 6...7: return "🔥"
        case 8...10: return "☠️"
        default: return "💀"
        }
    }
}

struct WidgetView: View {
    let entry: UVIndexEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, isTimerRunning: true, exposureStatus: "Safe", locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

#Preview(as: .systemMedium) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, isTimerRunning: true, exposureStatus: "Safe", locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

 