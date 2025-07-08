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
    init() {
        print("🌞 [Widget] 🚀 UVIndexProvider initialized")
    }
    
    func placeholder(in context: Context) -> UVIndexEntry {
        print("🌞 [Widget] 📱 Placeholder requested")
        return UVIndexEntry(date: Date(), uvIndex: nil, timeToBurn: nil, isTimerRunning: nil, exposureStatus: nil, locationName: nil, lastUpdated: nil, debugInfo: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (UVIndexEntry) -> Void) {
        print("🌞 [Widget] 📸 Snapshot requested")
        
        let sharedData = loadSharedDataWithDebug()
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
        
        if let data = sharedData {
            let uvEmoji = getUVEmoji(data.currentUVIndex)
            let timeToBurnText = data.timeToBurn == Int.max ? "∞" : "\(data.timeToBurn / 60)min"
            print("🌞 [Widget] 📸 Snapshot Created:")
            print("   📊 UV Index: \(uvEmoji) \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(data.locationName)")
            print("   ──────────────────────────────────────")
        } else {
            print("🌞 [Widget] 📸 ❌ No data available for snapshot")
        }
        
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVIndexEntry>) -> Void) {
        print("🌞 [Widget] ⏰ Timeline requested")
        
        let sharedData = loadSharedDataWithDebug()
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
            print("🌞 [Widget] ⏰ Timeline Entry Created:")
            print("   📊 UV Index: \(uvEmoji) \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(data.locationName)")
            print("   ──────────────────────────────────────")
        } else {
            print("🌞 [Widget] ⏰ ❌ No data available for timeline")
        }
        
        // Refresh every 2 minutes
        let nextUpdate = Date().addingTimeInterval(120)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Enhanced Data Loading with Debug
    
    private func loadSharedDataWithDebug() -> SharedUVData? {
        print("🌞 [Widget] 🔍 Attempting to load shared data...")
        
        // Try main UserDefaults first
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
            print("🌞 [Widget] ✅ Main UserDefaults initialized")
            
            if let data = userDefaults.data(forKey: "sharedUVData") {
                print("🌞 [Widget] 📦 Found data in UserDefaults (\(data.count) bytes)")
                
                if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                    let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                    let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                    print("🌞 [Widget] ✅ Successfully loaded shared data:")
                    print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                    print("   ⏱️  Time to Burn: \(timeToBurnText)")
                    print("   📍 Location: \(decoded.locationName)")
                    print("   ──────────────────────────────────────")
                    return decoded
                } else {
                    print("🌞 [Widget] ❌ Failed to decode data from main UserDefaults")
                }
            } else {
                print("🌞 [Widget] ⚠️  No data found in main UserDefaults")
            }
        } else {
            print("🌞 [Widget] ❌ Failed to initialize main UserDefaults")
        }
        
        // Try alternative UserDefaults
        print("🌞 [Widget] 🔄 Trying alternative UserDefaults...")
        if let alternativeUserDefaults = UserDefaults(suiteName: "group.Time-to-Burn.shared") {
            print("🌞 [Widget] ✅ Alternative UserDefaults initialized")
            
            if let data = alternativeUserDefaults.data(forKey: "sharedUVData") {
                print("🌞 [Widget] 📦 Found data in alternative UserDefaults (\(data.count) bytes)")
                
                if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                    let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                    let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                    print("🌞 [Widget] ✅ Successfully loaded shared data (Alternative):")
                    print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                    print("   ⏱️  Time to Burn: \(timeToBurnText)")
                    print("   📍 Location: \(decoded.locationName)")
                    print("   ──────────────────────────────────────")
                    return decoded
                } else {
                    print("🌞 [Widget] ❌ Failed to decode data from alternative UserDefaults")
                }
            } else {
                print("🌞 [Widget] ⚠️  No data found in alternative UserDefaults")
            }
        } else {
            print("🌞 [Widget] ❌ Failed to initialize alternative UserDefaults")
        }
        
        // Try standard UserDefaults as last resort
        print("🌞 [Widget] 🔄 Trying standard UserDefaults as last resort...")
        if let data = UserDefaults.standard.data(forKey: "sharedUVData") {
            print("🌞 [Widget] 📦 Found data in standard UserDefaults (\(data.count) bytes)")
            
            if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                print("🌞 [Widget] ✅ Successfully loaded shared data (Standard):")
                print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                print("   ⏱️  Time to Burn: \(timeToBurnText)")
                print("   📍 Location: \(decoded.locationName)")
                print("   ──────────────────────────────────────")
                return decoded
            } else {
                print("🌞 [Widget] ❌ Failed to decode data from standard UserDefaults")
            }
        } else {
            print("🌞 [Widget] ⚠️  No data found in standard UserDefaults")
        }
        
        print("🌞 [Widget] ❌ No shared data found in any UserDefaults")
        return nil
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

 