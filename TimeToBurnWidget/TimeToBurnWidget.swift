import WidgetKit
import SwiftUI

struct TimeToBurnWidget: Widget {
    let kind: String = "TimeToBurnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TimeToBurnWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Time to Burn")
        .description("Track your UV exposure time")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), uvIndex: 5, exposureTime: 0, maxTime: 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), uvIndex: 5, exposureTime: 0, maxTime: 60)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, uvIndex: 5, exposureTime: 0, maxTime: 60)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let uvIndex: Int
    let exposureTime: TimeInterval
    let maxTime: TimeInterval
}

struct TimeToBurnWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                Text("UV \(entry.uvIndex)")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Exposure Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTime(entry.exposureTime))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Text("Tap to open app")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .containerBackground(.fill, for: .widget)
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
}

#Preview(as: .systemSmall) {
    TimeToBurnWidget()
} timeline: {
    SimpleEntry(date: .now, uvIndex: 5, exposureTime: 1200, maxTime: 3600)
} 