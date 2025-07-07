import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UVIndexEntry
    @StateObject private var viewModel = WidgetViewModel()
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with location and updated time
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Text(entry.locationName ?? "Unknown")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    if let lastUpdated = entry.lastUpdated {
                        Text("Updated \(viewModel.formatHour(lastUpdated))")
                            .font(.system(size: 8))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                Spacer()
            }
            
            // Main UV Index display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UV Index")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Text("Time to Burn:")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    
                    Text(viewModel.getTimeToBurnText(entry.timeToBurn))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(viewModel.getUVColor(entry.uvIndex ?? 0).opacity(0.1))
        )
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
} 