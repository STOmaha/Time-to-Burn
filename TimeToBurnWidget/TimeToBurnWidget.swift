import WidgetKit
import SwiftUI

@available(iOS 17.0, *)
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
            .systemMedium,
            .systemLarge
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
        UVIndexEntry(date: Date(), uvIndex: nil, timeToBurn: nil, isTimerRunning: nil, exposureStatus: nil, locationName: nil, lastUpdated: nil, debugInfo: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let debugInfo = sharedData != nil ? "Snapshot: UV=\(sharedData!.currentUVIndex), TTB=\(sharedData!.timeToBurn)" : "Snapshot: No data"
        print("Widget: getSnapshot called - \(debugInfo)")
        
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            locationName: sharedData?.locationName,
            lastUpdated: sharedData?.lastUpdated,
            debugInfo: debugInfo
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let debugInfo = sharedData != nil ? "Timeline: UV=\(sharedData!.currentUVIndex), TTB=\(sharedData!.timeToBurn)" : "Timeline: No data"
        print("Widget: getTimeline called - \(debugInfo)")
        
        // Also print the raw UserDefaults data for debugging
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
            print("Widget: UserDefaults suite exists")
            if let data = userDefaults.data(forKey: "sharedUVData") {
                print("Widget: Raw data exists, size: \(data.count) bytes")
            } else {
                print("Widget: No raw data found in UserDefaults")
            }
        } else {
            print("Widget: UserDefaults suite not found")
        }
        
        let entry = UVIndexEntry(
            date: Date(), 
            uvIndex: sharedData?.currentUVIndex,
            timeToBurn: sharedData?.timeToBurn,
            isTimerRunning: sharedData?.isTimerRunning,
            exposureStatus: sharedData?.exposureStatus.rawValue,
            locationName: sharedData?.locationName,
            lastUpdated: sharedData?.lastUpdated,
            debugInfo: debugInfo
        )
        
        // Refresh every 15 minutes
        let nextUpdate = Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
        case .systemLarge:
            LargeWidgetView(entry: entry)
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

#Preview(as: .systemLarge) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, isTimerRunning: true, exposureStatus: "Safe", locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
} 