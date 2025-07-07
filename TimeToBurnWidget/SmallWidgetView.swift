import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: UVIndexEntry
    @StateObject private var viewModel = WidgetViewModel()
    
    var body: some View {
        VStack(spacing: 8) {
            // UV Index
            VStack(spacing: 2) {
                Text("UV Index")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
            }
            
            // Time to Burn
            VStack(spacing: 2) {
                Text("Time to Burn")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(viewModel.getTimeToBurnText(entry.timeToBurn))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
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