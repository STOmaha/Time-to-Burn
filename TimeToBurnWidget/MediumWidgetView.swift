import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UVIndexEntry
    @StateObject private var viewModel = WidgetViewModel()
    
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
                            Text("Updated \(viewModel.formatHour(lastUpdated))")
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
                        
                        Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
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
                        
                        Text(viewModel.getTimeToBurnText(entry.timeToBurn))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                    }
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            viewModel.getUVColor(entry.uvIndex ?? 0).opacity(0.15)
        }
    }
} 