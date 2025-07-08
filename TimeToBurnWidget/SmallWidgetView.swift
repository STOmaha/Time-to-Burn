import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(entry.uvIndex)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(UVColorUtils.getUVColor(entry.uvIndex))
            Text("UV Index")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            Text(timeToBurnString)
                .font(.title3)
                .foregroundColor(.primary)
        }
        .padding()
        .containerBackground(for: .widget) {
            UVColorUtils.getUVColor(entry.uvIndex).opacity(0.12)
        }
    }
    
    private var timeToBurnString: String {
        if entry.timeToBurn <= 0 { return "∞" }
        let minutes = entry.timeToBurn / 60
        return "\(minutes) min"
    }
} 