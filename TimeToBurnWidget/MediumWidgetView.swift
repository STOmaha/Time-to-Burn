import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        let uvColor = UVColorUtils.getUVColor(entry.uvIndex)
        HStack(alignment: .center) {
            // Left column: UV Index, number, severity
            VStack(alignment: .center, spacing: 6) {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(uvColor)
                Text("\(entry.uvIndex)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(uvColor)
                Text(UVColorUtils.getUVCategory(for: entry.uvIndex))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(uvColor)
            }
            .frame(maxWidth: .infinity)
            
            // Right column: Location, updated, time to burn
            VStack(alignment: .center, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(uvColor)
                    Text(entry.locationName)
                        .font(.subheadline)
                        .foregroundColor(uvColor)
                        .lineLimit(1)
                }
                Text("Updated \(lastUpdatedString)")
                    .font(.caption)
                    .foregroundColor(uvColor)
                    .padding(.bottom, 20)
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption)
                        .foregroundColor(uvColor)
                    Text("Time to Burn:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(uvColor)
                }
                Text(timeToBurnString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(uvColor)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .containerBackground(for: .widget) {
            uvColor.opacity(0.12)
        }
    }
    
    private var timeToBurnString: String {
        if entry.uvIndex == 0 { return "∞" }
        if entry.timeToBurn <= 0 || entry.timeToBurn == Int.max { return "∞" }
        let minutes = entry.timeToBurn / 60
        print("🌞 [MediumWidget] 📊 UV: \(entry.uvIndex), Time to Burn: \(minutes)min")
        return "\(minutes) min"
    }
    
    private var lastUpdatedString: String {
        UVColorUtils.formatHour(entry.lastUpdated)
    }
} 