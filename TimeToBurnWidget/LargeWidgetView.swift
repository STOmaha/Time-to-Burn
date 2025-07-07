import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: UVIndexEntry
    @StateObject private var viewModel = WidgetViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
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
            
            // Current UV Index and Time to Burn
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UV Index")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(entry.uvIndex != nil ? "\(entry.uvIndex!)" : "--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Time to Burn")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.getTimeToBurnText(entry.timeToBurn))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.getUVColor(entry.uvIndex ?? 0))
                }
            }
            
            // UV Chart
            UVChartWidgetView(viewModel: viewModel)
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

struct UVChartWidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    
    private let chartHeight: CGFloat = 120
    private let chartPadding: CGFloat = 8
    private let yMax: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 4) {
            // Chart title
            HStack {
                Text("Today's UV Forecast")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Chart area
            GeometryReader { geo in
                Canvas { context, size in
                    let chartRect = CGRect(x: chartPadding, y: chartPadding, width: size.width - 2*chartPadding, height: chartHeight)
                    let uvData = viewModel.getChartUVData()
                    guard uvData.count > 1 else { return }
                    
                    // Draw Y-axis ticks and labels
                    for y in stride(from: 0, through: Int(yMax), by: 3) {
                        let yPos = chartRect.maxY - chartRect.height * CGFloat(y) / yMax
                        // Tick
                        let tick = Path { path in
                            path.move(to: CGPoint(x: chartRect.maxX, y: yPos))
                            path.addLine(to: CGPoint(x: chartRect.maxX + 4, y: yPos))
                        }
                        context.stroke(tick, with: .color(.gray), lineWidth: 1)
                        // Label
                        let label = Text("\(y)").font(.system(size: 8)).foregroundColor(.secondary)
                        let resolved = context.resolve(label)
                        let textSize = resolved.measure(in: CGSize(width: 20, height: 12))
                        let textPoint = CGPoint(x: chartRect.maxX + 6, y: yPos - textSize.height/2)
                        context.draw(resolved, at: textPoint)
                    }
                    
                    // Draw X-axis ticks and labels
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: uvData.first!.date)
                    for hour in stride(from: 6, through: 20, by: 4) {
                        guard let tickDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
                        let totalSeconds = uvData.last!.date.timeIntervalSince(uvData.first!.date)
                        let tickSeconds = tickDate.timeIntervalSince(uvData.first!.date)
                        let fraction = CGFloat(tickSeconds / totalSeconds)
                        let x = chartRect.minX + chartRect.width * fraction
                        // Tick
                        let tick = Path { path in
                            path.move(to: CGPoint(x: x, y: chartRect.maxY))
                            path.addLine(to: CGPoint(x: x, y: chartRect.maxY + 4))
                        }
                        context.stroke(tick, with: .color(.gray), lineWidth: 1)
                        // Label
                        let hourLabel: String
                        if hour == 12 {
                            hourLabel = "12p"
                        } else if hour < 12 {
                            hourLabel = "\(hour)a"
                        } else {
                            hourLabel = "\(hour-12)p"
                        }
                        let label = Text(hourLabel).font(.system(size: 8)).foregroundColor(.secondary)
                        let resolved = context.resolve(label)
                        let textSize = resolved.measure(in: CGSize(width: 24, height: 10))
                        let textPoint = CGPoint(x: x - textSize.width/2, y: chartRect.maxY + 6)
                        context.draw(resolved, at: textPoint)
                    }
                    
                    // Draw grid lines
                    for y in stride(from: 0, through: yMax, by: 3) {
                        let yPos = chartRect.maxY - chartRect.height * CGFloat(y) / yMax
                        let line = Path { path in
                            path.move(to: CGPoint(x: chartRect.minX, y: yPos))
                            path.addLine(to: CGPoint(x: chartRect.maxX, y: yPos))
                        }
                        context.stroke(line, with: .color(Color.gray.opacity(0.15)), lineWidth: 1)
                    }
                    
                    // Collect points for UV curve
                    let uvPoints = uvData.map { point in
                        CGPoint(
                            x: chartRect.minX + chartRect.width * CGFloat(point.fraction),
                            y: chartRect.maxY - chartRect.height * CGFloat(point.uv) / yMax
                        )
                    }
                    
                    // Draw UV curve
                    if uvPoints.count > 1 {
                        let uvPath = Path { path in
                            path.move(to: uvPoints[0])
                            for i in 1..<uvPoints.count {
                                path.addLine(to: uvPoints[i])
                            }
                        }
                        context.stroke(uvPath, with: .linearGradient(
                            Gradient(colors: uvPoints.enumerated().map { viewModel.getUVColor(uvData[$0.offset].uv) }),
                            startPoint: uvPoints.first ?? .zero,
                            endPoint: uvPoints.last ?? .zero
                        ), lineWidth: 3)
                    }
                    
                    // Draw current time indicator
                    let now = Date()
                    let calendar2 = Calendar.current
                    let currentHour = calendar2.component(.hour, from: now)
                    if currentHour >= 6 && currentHour <= 20 {
                        let totalSeconds = uvData.last!.date.timeIntervalSince(uvData.first!.date)
                        let nowSeconds = now.timeIntervalSince(uvData.first!.date)
                        let fraction = CGFloat(nowSeconds / totalSeconds)
                        let nowX = chartRect.minX + chartRect.width * fraction
                        let nowLine = Path { path in
                            path.move(to: CGPoint(x: nowX, y: chartRect.minY))
                            path.addLine(to: CGPoint(x: nowX, y: chartRect.maxY))
                        }
                        context.stroke(nowLine, with: .color(.blue), lineWidth: 2)
                    }
                }
                .frame(height: chartHeight + 2*chartPadding + 10)
            }
        }
    }
} 