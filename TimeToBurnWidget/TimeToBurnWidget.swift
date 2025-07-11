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
    init() {
        print("🌞 [Widget] 🚀 SimpleUVIndexProvider initialized")
    }
    
    func placeholder(in context: Context) -> UVIndexEntry {
        print("🌞 [Widget] 📱 Placeholder requested")
        return UVIndexEntry(
            date: Date(), 
            uvIndex: 4,
            timeToBurn: 2700,
            locationName: "Loading...",
            lastUpdated: Date(),
            debugInfo: "Placeholder"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        print("🌞 [Widget] 📸 Snapshot requested")
        
        let entry = loadSharedDataDirectly()
        print("🌞 [Widget] 📸 Snapshot Created: UV=\(entry.uvIndex), Time=\(entry.timeToBurn/60)min, Location=\(entry.locationName)")
        
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        print("🌞 [Widget] ⏰ Timeline requested")
        
        let entry = loadSharedDataDirectly()
        print("🌞 [Widget] ⏰ Timeline Entry Created: UV=\(entry.uvIndex), Time=\(entry.timeToBurn/60)min, Location=\(entry.locationName)")
        
        // Create multiple timeline entries to ensure widget updates regularly
        var entries: [UVIndexEntry] = []
        
        // Current entry
        entries.append(entry)
        
        // Future entries every 30 minutes for the next 2 hours
        for i in 1...4 {
            let futureDate = Date().addingTimeInterval(TimeInterval(i * 1800)) // 30 minutes * i
            let futureEntry = UVIndexEntry(
                date: futureDate,
                uvIndex: entry.uvIndex,
                timeToBurn: entry.timeToBurn,
                locationName: entry.locationName,
                lastUpdated: entry.lastUpdated,
                debugInfo: "Future entry \(i)"
            )
            entries.append(futureEntry)
        }
        
        // Set policy to refresh every 30 minutes
        let nextUpdate = Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Direct Data Loading
    
    private func loadSharedDataDirectly() -> UVIndexEntry {
        print("🌞 [Widget] 🔍 Loading shared data directly...")
        
        // Debug data sources for troubleshooting
        debugDataSources()
        
        // Try to load from shared data manager first (most reliable)
        if let sharedData = WidgetSharedDataManager.shared.loadSharedData() {
            print("🌞 [Widget] ✅ Successfully loaded shared data: UV=\(sharedData.currentUVIndex)")
            return UVIndexEntry(
                date: Date(),
                uvIndex: sharedData.currentUVIndex,
                timeToBurn: sharedData.timeToBurn,
                locationName: sharedData.locationName,
                lastUpdated: sharedData.lastUpdated,
                debugInfo: "Loaded from SharedDataManager"
            )
        }
        
        // Fallback: Try direct UserDefaults access
        print("🌞 [Widget] 🔄 Trying direct UserDefaults access...")
        
        // Try main app group
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared"),
           let data = userDefaults.data(forKey: "sharedUVData"),
           let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
            print("🌞 [Widget] ✅ Loaded from app group UserDefaults: UV=\(decoded.currentUVIndex)")
            return UVIndexEntry(
                date: Date(),
                uvIndex: decoded.currentUVIndex,
                timeToBurn: decoded.timeToBurn,
                locationName: decoded.locationName,
                lastUpdated: decoded.lastUpdated,
                debugInfo: "Loaded from app group UserDefaults"
            )
        }
        
        // Try standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: "sharedUVData"),
           let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
            print("🌞 [Widget] ✅ Loaded from standard UserDefaults: UV=\(decoded.currentUVIndex)")
            return UVIndexEntry(
                date: Date(),
                uvIndex: decoded.currentUVIndex,
                timeToBurn: decoded.timeToBurn,
                locationName: decoded.locationName,
                lastUpdated: decoded.lastUpdated,
                debugInfo: "Loaded from standard UserDefaults"
            )
        }
        
        // Default fallback with more informative debug info
        print("🌞 [Widget] ❌ No shared data found, using defaults")
        return UVIndexEntry(
            date: Date(),
            uvIndex: 0,
            timeToBurn: 0,
            locationName: "No Data",
            lastUpdated: Date(),
            debugInfo: "No data available - check main app has run and saved data"
        )
    }
    
    // MARK: - Debug Helper
    private func debugDataSources() {
        print("🌞 [Widget] 🔍 Debugging data sources...")
        
        // Check app group UserDefaults
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
            if let data = userDefaults.data(forKey: "sharedUVData") {
                print("🌞 [Widget] ✅ App group has data: \(data.count) bytes")
                if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                    print("🌞 [Widget] ✅ App group data decodable: UV=\(decoded.currentUVIndex)")
                } else {
                    print("🌞 [Widget] ❌ App group data not decodable")
                }
            } else {
                print("🌞 [Widget] ❌ App group has no data")
            }
        } else {
            print("🌞 [Widget] ❌ App group UserDefaults not accessible")
        }
        
        // Check standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: "sharedUVData") {
            print("🌞 [Widget] ✅ Standard UserDefaults has data: \(data.count) bytes")
        } else {
            print("🌞 [Widget] ❌ Standard UserDefaults has no data")
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
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

#Preview(as: .systemMedium) {
    TimeToBurnWidget()
} timeline: {
    UVIndexEntry(date: .now, uvIndex: 5, timeToBurn: 120, locationName: "San Francisco", lastUpdated: Date(), debugInfo: "Preview data")
}

 
 