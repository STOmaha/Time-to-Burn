import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UVIndexEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.locationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(entry.uvIndex)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(UVColorUtils.getUVColor(entry.uvIndex))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Time to Burn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timeToBurnString)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            Spacer(minLength: 0)
            Text("Updated \(lastUpdatedString)")
                .font(.footnote)
                .foregroundColor(.secondary)
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
    private var lastUpdatedString: String {
        UVColorUtils.formatHour(entry.lastUpdated)
    }
} 