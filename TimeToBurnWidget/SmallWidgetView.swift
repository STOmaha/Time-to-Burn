import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: UVIndexEntry
    @StateObject private var viewModel = WidgetViewModel()
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // UV Index
                VStack(spacing: 2) {
                    Text("UV Index")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "0")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
                
                // Time to Burn
                VStack(spacing: 2) {
                    Text("Time to Burn")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Text(viewModel.getTimeToBurnText(entry.timeToBurn))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            viewModel.getUVColor(entry.uvIndex ?? 0).opacity(0.15)
        }
    }
} 