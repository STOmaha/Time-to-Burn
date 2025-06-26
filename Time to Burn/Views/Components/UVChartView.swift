import SwiftUI

struct UVChartCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    var body: some View {
        UVChartView()
            .environmentObject(weatherViewModel)
            .padding(20)
    }
}

struct UVChartView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    var data: [UVData]? = nil
    @GestureState private var dragOffset: CGFloat? = nil
    @State private var selectedFraction: CGFloat? = nil // 0...1, nil = current time
    @State private var isDragging = false
    @Namespace private var animation
    
    @State private var userThreshold: Int = UserDefaults.standard.integer(forKey: "uvUserThreshold") == 0 ? 6 : UserDefaults.standard.integer(forKey: "uvUserThreshold")
    
    private let chartHeight: CGFloat = 180
    private let chartPadding: CGFloat = 24
    private let yAxisMargin: CGFloat = 40 // Space for Y-axis labels on the right
    private let yMax: CGFloat = 12
    private let avoidStartHour = 11
    private let avoidEndHour = 15
    
    var body: some View {
        let selectedUV = getSelectedUV()
        let pastelColor = UVColorUtils.getPastelUVColor(selectedUV)
        
        VStack(spacing: 16) {
            // Now/Selected time and UV index
            HStack(spacing: 8) {
                let (displayTime, displayUV, displayColor) = getDisplayTimeUV()
                Text(isDragging ? "Selected:" : "Now:")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(displayTime)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                if let uv = displayUV {
                    Text("• UV \(uv)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(displayColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Chart area
            GeometryReader { geo in
                ZStack {
                    // Dynamic pastel background
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(pastelColor)
                        .shadow(color: pastelColor.opacity(0.18), radius: 16, x: 0, y: 8)
                    // Chart drawing
                    Canvas { context, size in
                        let chartRect = CGRect(x: chartPadding, y: chartPadding, width: size.width - 2*chartPadding, height: chartHeight)
                        let uvData = getChartUVData()
                        guard uvData.count > 1 else { return }
                        
                        // Draw Y-axis ticks and labels (0, 2, ..., 12) on the right side
                        for y in stride(from: 0, through: Int(yMax), by: 2) {
                            let yPos = chartRect.maxY - chartRect.height * CGFloat(y) / yMax
                            // Tick on the right
                            let tick = Path { path in
                                path.move(to: CGPoint(x: chartRect.maxX, y: yPos))
                                path.addLine(to: CGPoint(x: chartRect.maxX + 8, y: yPos))
                            }
                            context.stroke(tick, with: .color(.gray), lineWidth: 1)
                            // Label on the right
                            let label = Text("\(y)").font(.caption2).foregroundColor(.secondary)
                            let resolved = context.resolve(label)
                            let textSize = resolved.measure(in: CGSize(width: 30, height: 16))
                            let textPoint = CGPoint(x: chartRect.maxX + 12, y: yPos - textSize.height/2)
                            context.draw(resolved, at: textPoint)
                        }
                        // Draw X-axis ticks and labels (every 3 hours)
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: uvData.first!.date)
                        for hour in stride(from: 0, through: 24, by: 3) {
                            guard let tickDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
                            let totalSeconds = uvData.last!.date.timeIntervalSince(uvData.first!.date)
                            let tickSeconds = tickDate.timeIntervalSince(uvData.first!.date)
                            let fraction = CGFloat(tickSeconds / totalSeconds)
                            let x = chartRect.minX + chartRect.width * fraction
                            // Tick
                            let tick = Path { path in
                                path.move(to: CGPoint(x: x, y: chartRect.maxY))
                                path.addLine(to: CGPoint(x: x, y: chartRect.maxY + 6))
                            }
                            context.stroke(tick, with: .color(.gray), lineWidth: 1)
                            // Label
                            let hourLabel: String
                            if hour == 0 || hour == 24 {
                                hourLabel = "12am"
                            } else if hour == 12 {
                                hourLabel = "12pm"
                            } else if hour < 12 {
                                hourLabel = "\(hour)am"
                            } else {
                                hourLabel = "\(hour-12)pm"
                            }
                            let label = Text(hourLabel).font(.caption2).foregroundColor(.secondary)
                            let resolved = context.resolve(label)
                            let textSize = resolved.measure(in: CGSize(width: 32, height: 12))
                            let textPoint = CGPoint(x: x - textSize.width/2, y: chartRect.maxY + 8)
                            context.draw(resolved, at: textPoint)
                        }
                        // Draw grid lines
                        for y in stride(from: 0, through: yMax, by: 2) {
                            let yPos = chartRect.maxY - chartRect.height * CGFloat(y) / yMax
                            let line = Path { path in
                                path.move(to: CGPoint(x: chartRect.minX, y: yPos))
                                path.addLine(to: CGPoint(x: chartRect.maxX, y: yPos))
                            }
                            context.stroke(line, with: .color(Color.gray.opacity(0.18)), lineWidth: 1)
                        }
                        // Draw threshold line
                        let thresholdY = chartRect.maxY - chartRect.height * CGFloat(userThreshold) / yMax
                        let thresholdLine = Path { path in
                            path.move(to: CGPoint(x: chartRect.minX, y: thresholdY))
                            path.addLine(to: CGPoint(x: chartRect.maxX, y: thresholdY))
                        }
                        context.stroke(thresholdLine, with: .color(.red), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        // Threshold label
                        let labelHeight: CGFloat = 18
                        let labelRect = CGRect(x: chartRect.minX + 6, y: thresholdY - labelHeight/2, width: 80, height: labelHeight)
                        // Draw background
                        let labelBg = Path(roundedRect: labelRect, cornerRadius: 6)
                        context.fill(labelBg, with: .color(.red))
                        // Draw text centered in labelRect
                        let resolved = context.resolve(Text("UV Threshold").font(.caption2).foregroundColor(.white))
                        let textSize = resolved.measure(in: labelRect.size)
                        let textPoint = CGPoint(x: labelRect.midX - textSize.width/2, y: labelRect.midY - textSize.height/2)
                        context.draw(resolved, at: textPoint)
                        
                        // Draw UV line as gradient
                        var uvPath = Path()
                        for (i, point) in uvData.enumerated() {
                            let x = chartRect.minX + chartRect.width * CGFloat(point.fraction)
                            let y = chartRect.maxY - chartRect.height * CGFloat(point.uv) / yMax
                            if i == 0 {
                                uvPath.move(to: CGPoint(x: x, y: y))
                            } else {
                                uvPath.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        // Draw per-segment gradient
                        for i in 1..<uvData.count {
                            let prev = uvData[i-1]
                            let curr = uvData[i]
                            let x1 = chartRect.minX + chartRect.width * CGFloat(prev.fraction)
                            let y1 = chartRect.maxY - chartRect.height * CGFloat(prev.uv) / yMax
                            let x2 = chartRect.minX + chartRect.width * CGFloat(curr.fraction)
                            let y2 = chartRect.maxY - chartRect.height * CGFloat(curr.uv) / yMax
                            let color1 = getChartColor(for: prev.uv)
                            let color2 = getChartColor(for: curr.uv)
                            let segPath = Path { path in
                                path.move(to: CGPoint(x: x1, y: y1))
                                path.addLine(to: CGPoint(x: x2, y: y2))
                            }
                            let gradient = Gradient(colors: [color1, color2])
                            context.stroke(segPath, with: .linearGradient(gradient, startPoint: CGPoint(x: x1, y: y1), endPoint: CGPoint(x: x2, y: y2)), lineWidth: 4)
                        }
                        // Draw vertical Now/Selected line
                        let nowFraction = getNowFraction()
                        let selected = selectedFraction ?? nowFraction
                        let nowX = chartRect.minX + chartRect.width * selected
                        let nowLine = Path { path in
                            path.move(to: CGPoint(x: nowX, y: chartRect.minY))
                            path.addLine(to: CGPoint(x: nowX, y: chartRect.maxY))
                        }
                        context.stroke(nowLine, with: .color(.blue), lineWidth: 2)
                    }
                    .frame(height: chartHeight + 2*chartPadding + 24)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragOffset) { value, state, _ in
                                let geoWidth = geo.size.width - 2*chartPadding
                                let x = min(max(value.location.x - chartPadding, 0), geoWidth)
                                state = x / geoWidth
                            }
                            .onChanged { value in
                                isDragging = true
                                let geoWidth = geo.size.width - 2*chartPadding
                                let x = min(max(value.location.x - chartPadding, 0), geoWidth)
                                selectedFraction = x / geoWidth
                            }
                            .onEnded { _ in
                                isDragging = false
                                withAnimation(.easeOut(duration: 0.6)) {
                                    selectedFraction = nil
                                }
                            }
                    )
                }
            }
            .frame(height: chartHeight + 2*chartPadding + 24)
            // Notification threshold and slider
            VStack(spacing: 8) {
                HStack {
                    Text("Notification Threshold:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("UV \(userThreshold)")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                // Time to Burn Estimate (moved above slider)
                Text("Time to Burn at this threshold: ~\(getTimeToBurnString(for: userThreshold))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(userThreshold) },
                    set: { newValue in
                        userThreshold = Int(newValue.rounded())
                        UserDefaults.standard.set(userThreshold, forKey: "uvUserThreshold")
                    }
                ), in: 1...11, step: 1)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helper Functions
    private func getChartUVData() -> [(fraction: CGFloat, uv: Int, date: Date)] {
        let calendar = Calendar.current
        let usedData: [UVData]
        if let data = data {
            usedData = data
        } else {
            let today = Date()
            usedData = weatherViewModel.hourlyUVData.filter { calendar.isDate($0.date, inSameDayAs: today) }
        }
        guard let first = usedData.first, let last = usedData.last else { return [] }
        let totalSeconds = last.date.timeIntervalSince(first.date)
        return usedData.map { d in
            let fraction = CGFloat(d.date.timeIntervalSince(first.date) / totalSeconds)
            return (fraction, d.uvIndex, d.date)
        }
    }
    private func getNowFraction() -> CGFloat {
        let uvData = getChartUVData()
        guard let first = uvData.first, let last = uvData.last else { return 0 }
        let now = Date()
        let totalSeconds = last.date.timeIntervalSince(first.date)
        let nowSeconds = now.timeIntervalSince(first.date)
        return CGFloat(min(max(nowSeconds / totalSeconds, 0), 1))
    }
    private func getDisplayTimeUV() -> (String, Int?, Color) {
        let uvData = getChartUVData()
        guard uvData.count > 1 else { return ("--", nil, .gray) }
        let fraction = selectedFraction ?? getNowFraction()
        let idx = Int(round(fraction * CGFloat(uvData.count - 1)))
        let point = uvData[min(max(idx, 0), uvData.count - 1)]
        let time = formatHour(point.date)
        let color = getChartColor(for: point.uv)
        return (time, point.uv, color)
    }
    private func getChartColor(for uvIndex: Int) -> Color {
        UVColorUtils.getUVColor(uvIndex)
    }
    private func formatHour(_ date: Date) -> String {
        UVColorUtils.formatHour(date)
    }
    private func getTimeToBurnString(for uv: Int) -> String {
        if uv == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurn(uvIndex: uv)
        return "\(minutes) minutes"
    }
    private func getSelectedUV() -> Int {
        let uvData = getChartUVData()
        guard uvData.count > 1 else { return 0 }
        let fraction = selectedFraction ?? getNowFraction()
        let idx = Int(round(fraction * CGFloat(uvData.count - 1)))
        let point = uvData[min(max(idx, 0), uvData.count - 1)]
        return point.uv
    }
} 