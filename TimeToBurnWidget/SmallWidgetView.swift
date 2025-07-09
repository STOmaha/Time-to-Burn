import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        let uvColor = UVColorUtils.getUVColor(entry.uvIndex)
        VStack(spacing: 3) {
            // UV Index number
            Text("\(entry.uvIndex)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(uvColor)
            // UV Category text (e.g., "Very High")
            Text(UVColorUtils.getUVCategory(for: entry.uvIndex))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(uvColor)
            // Time to Burn label
            Text("Time to Burn")
                .font(.callout)
                .foregroundColor(uvColor)
            // Time to Burn value
            Text(timeToBurnString)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(uvColor)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            uvColor.opacity(0.12)
        }
    }
    
    private var timeToBurnString: String {
        if entry.uvIndex == 0 { return "∞" }
        if entry.timeToBurn <= 0 { return "∞" }
        let minutes = entry.timeToBurn / 60
        return "\(minutes) min"
    }
} 