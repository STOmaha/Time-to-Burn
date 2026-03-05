import WidgetKit
import SwiftUI

struct TimeToBurnWidget: Widget {
    let kind: String = "TimeToBurnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleUVIndexProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Current UV Index")
        .description("Shows the current UV Index from the main app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

struct UVIndexEntry: TimelineEntry {
    let date: Date
    let uvIndex: Int
    let timeToBurn: Int
    let locationName: String
    let lastUpdated: Date
    let debugInfo: String
}

struct SimpleUVIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVIndexEntry {
        UVIndexEntry(
            date: Date(),
            uvIndex: 4,
            timeToBurn: 2700,
            locationName: "Loading...",
            lastUpdated: Date(),
            debugInfo: "Placeholder"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        let entry = loadEntry()

        // Create timeline entries for the next hour
        var entries: [UVIndexEntry] = [entry]
        for i in 1...4 {
            let futureDate = Date().addingTimeInterval(TimeInterval(i * 900))
            entries.append(UVIndexEntry(
                date: futureDate,
                uvIndex: entry.uvIndex,
                timeToBurn: entry.timeToBurn,
                locationName: entry.locationName,
                lastUpdated: entry.lastUpdated,
                debugInfo: "Future entry \(i)"
            ))
        }

        let nextUpdate = Date().addingTimeInterval(900)
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }

    // MARK: - Lightweight Data Loading

    private func loadEntry() -> UVIndexEntry {
        // Use lightweight data loader (no singletons, no WeatherKit)
        guard let sharedData = WidgetDataLoader.loadSharedData() else {
            return UVIndexEntry(
                date: Date(),
                uvIndex: 0,
                timeToBurn: 0,
                locationName: "No Data",
                lastUpdated: Date(),
                debugInfo: "No data available"
            )
        }

        // Validate timeToBurn
        var timeToBurn = sharedData.timeToBurn
        let maxReasonableTime = 86400

        if sharedData.currentUVIndex == 0 {
            timeToBurn = 0
        } else if timeToBurn < 0 || timeToBurn > maxReasonableTime {
            timeToBurn = max(60, 3600 / max(1, sharedData.currentUVIndex))
        }

        return UVIndexEntry(
            date: Date(),
            uvIndex: sharedData.currentUVIndex,
            timeToBurn: timeToBurn,
            locationName: sharedData.locationName,
            lastUpdated: sharedData.lastUpdated,
            debugInfo: "Loaded"
        )
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
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

#Preview(as: .systemMedium) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

 
 