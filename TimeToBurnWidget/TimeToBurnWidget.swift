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
}

struct UVIndexProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVIndexEntry {
        UVIndexEntry(date: Date(), uvIndex: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let entry = UVIndexEntry(date: Date(), uvIndex: sharedData?.currentUVIndex)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        let sharedData = SharedDataManager.shared.loadSharedData()
        let entry = UVIndexEntry(date: Date(), uvIndex: sharedData?.currentUVIndex)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        completion(timeline)
    }
}

struct UVIndexWidgetView: View {
    let entry: UVIndexEntry
    var body: some View {
        VStack(spacing: 8) {
            Text("UV Index")
                .font(.headline)
            Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview(as: .systemSmall) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5)
} 