import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // Header with location and updated time
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text(entry.locationName ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .fontWeight(.medium)
                        }
                        if let lastUpdated = entry.lastUpdated {
                            Text("Updated \(formatHour(lastUpdated))")
                                .font(.caption2)
                                .foregroundColor(.primary.opacity(0.7))
                        }
                    }
                    Spacer()
                }
                
                // Main UV Index display
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UV Index")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        
                        Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "0")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(getUVColor(entry.uvIndex ?? 0))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("Time to Burn:")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        
                        Text(getTimeToBurnText(entry.timeToBurn))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(getUVColor(entry.uvIndex ?? 0))
                    }
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            getUVColor(entry.uvIndex ?? 0).opacity(0.15)
        }
    }
    
    // Helper functions
    func getUVColor(_ uvIndex: Int) -> Color {
        // Color stops for UV 0 to 12+ - matching the main app exactly
        let stops: [(uv: Int, color: Color)] = [
            (0, Color(red: 0.0, green: 0.2, blue: 0.7)),        // #002366
            (1, Color(red: 0.0, green: 0.34, blue: 0.72)),      // #0057B7
            (2, Color(red: 0.0, green: 0.72, blue: 0.72)),      // #00B7B7
            (3, Color(red: 0.0, green: 0.72, blue: 0.0)),       // #00B700
            (4, Color(red: 0.65, green: 0.84, blue: 0.0)),      // #A7D700
            (5, Color(red: 1.0, green: 0.84, blue: 0.0)),       // #FFD700
            (6, Color(red: 1.0, green: 0.72, blue: 0.0)),       // #FFB700
            (7, Color(red: 1.0, green: 0.5, blue: 0.0)),        // #FF7F00
            (8, Color(red: 1.0, green: 0.27, blue: 0.0)),       // #FF4500
            (9, Color(red: 1.0, green: 0.0, blue: 0.0)),        // #FF0000
            (10, Color(red: 0.78, green: 0.0, blue: 0.63)),     // #C800A1
            (11, Color(red: 0.5, green: 0.0, blue: 0.5)),       // #800080
            (12, Color.black)                                   // #000000
        ]
        if uvIndex <= 0 { return stops[0].color }
        if uvIndex >= 12 { return stops.last!.color }
        // For integer UV, just return lower
        let lower = stops[uvIndex]
        return lower.color
    }
    
    func getTimeToBurnText(_ timeToBurn: Int?) -> String {
        guard let timeToBurn = timeToBurn, timeToBurn > 0 else {
            return "∞"
        }
        // Convert seconds to minutes
        let minutes = timeToBurn / 60
        return "\(minutes) min"
    }
    
    func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
} 