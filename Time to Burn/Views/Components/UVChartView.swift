import SwiftUI

struct UVChartCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    var body: some View {
        UVChartView()
            .environmentObject(weatherViewModel)
    }
}

struct CustomSliderThumb: View {
    var body: some View {
        Image("AngrySun")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .shadow(radius: 2)
    }
}

struct UVChartView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    var data: [UVData]? = nil
    @GestureState private var dragOffset: CGFloat? = nil
    @State private var selectedFraction: CGFloat? = nil // 0...1, nil = current time
    @State private var isDragging = false
    @State private var currentTime = Date() // Track current time for real-time updates
    @Namespace private var animation
    
    @State private var userThreshold: Int = UserDefaults.standard.integer(forKey: "uvUserThreshold") == 0 ? 6 : UserDefaults.standard.integer(forKey: "uvUserThreshold")
    
    private let chartHeight: CGFloat = 180
    private let chartPadding: CGFloat = 12
    private let yAxisMargin: CGFloat = 40 // Space for Y-axis labels on the right
    private let yMax: CGFloat = 12
    private let avoidStartHour = 11
    private let avoidEndHour = 15
    
    var body: some View {
        VStack(spacing: 10) {
            // Now/Selected time and UV index
            VStack(alignment: .leading, spacing: 4) {
                let (displayTime, displayUV, displayColor) = getDisplayTimeUV()
                HStack(spacing: 8) {
                Text(isDragging ? "Selected:" : "Now:")
                    .font(.headline)
                    .fontWeight(.medium)
                        .foregroundColor(displayColor)
                    Text(displayTime)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(displayColor)
                    if let uv = displayUV {
                        Text("• UV \(uv)")
                        .font(.headline)
                        .fontWeight(.semibold)
                            .foregroundColor(displayColor)
                    }
                }
                

                if let uv = displayUV {
                    Text("Time to Burn: \(getTimeToBurnString(for: uv))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(displayColor.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Chart area
            GeometryReader { geo in
                ZStack {
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
                            let textPoint = CGPoint(x: chartRect.maxX + 2, y: yPos - textSize.height/2)
                            context.draw(resolved, at: textPoint)
                        }
                        // Draw X-axis ticks and labels (every 3 hours)
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: uvData.first!.date)
                        for hour in stride(from: 0, through: 24, by: 6) {
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
                            let textPoint = CGPoint(x: x - textSize.width/2, y: chartRect.maxY + 12)
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
                        
                        // Draw danger zone bars only where UV is above threshold
                        for i in 1..<uvData.count {
                            let prev = uvData[i-1]
                            let curr = uvData[i]
                            
                            // Only draw if either point is above threshold
                            if prev.uv > userThreshold || curr.uv > userThreshold {
                                let x1 = chartRect.minX + chartRect.width * CGFloat(prev.fraction)
                                let x2 = chartRect.minX + chartRect.width * CGFloat(curr.fraction)
                                
                                // Calculate the UV values at each point
                                let y1 = chartRect.maxY - chartRect.height * CGFloat(prev.uv) / yMax
                                let y2 = chartRect.maxY - chartRect.height * CGFloat(curr.uv) / yMax
                                
                                // Create a rectangle from the threshold line up to the UV curve
                                let dangerBar = Path { path in
                                    path.move(to: CGPoint(x: x1, y: thresholdY))
                                    path.addLine(to: CGPoint(x: x2, y: thresholdY))
                                    path.addLine(to: CGPoint(x: x2, y: y2))
                                    path.addLine(to: CGPoint(x: x1, y: y1))
                                    path.closeSubpath()
                                }
                                context.fill(dangerBar, with: .color(.red.opacity(0.2)))
                            }
                        }
                        
                        // Threshold label
                        let labelHeight: CGFloat = 18
                        let labelRect = CGRect(x: chartRect.minX - 10, y: thresholdY - labelHeight/2, width: 80, height: labelHeight)
                        // Draw background
                        let labelBg = Path(roundedRect: labelRect, cornerRadius: 6)
                        context.fill(labelBg, with: .color(.red))
                        // Draw text centered in labelRect
                        let resolved = context.resolve(Text("UV Threshold").font(.caption2).foregroundColor(.white))
                        let _ = resolved.measure(in: labelRect.size)
                        let textPoint = CGPoint(x: labelRect.midX, y: labelRect.midY)
                        context.draw(resolved, at: textPoint)
                        
                        // Collect points
                        let uvPoints = uvData.map { point in
                            CGPoint(
                                x: chartRect.minX + chartRect.width * CGFloat(point.fraction),
                                y: chartRect.maxY - chartRect.height * CGFloat(point.uv) / yMax
                            )
                        }
                        let smoothUVPath = catmullRomSpline(points: uvPoints)
                        context.stroke(smoothUVPath, with: .linearGradient(Gradient(colors: uvPoints.enumerated().map { getChartColor(for: uvData[$0.offset].uv) }), startPoint: uvPoints.first ?? .zero, endPoint: uvPoints.last ?? .zero), lineWidth: 6)
                        
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
                    .frame(height: chartHeight + 2*chartPadding + 12)
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
                                let nowFraction = getNowFraction()
                                guard let start = selectedFraction else {
                                    selectedFraction = nil
                                    return
                                }
                                let animationDuration = 0.1
                                let animationSteps = 60
                                let stepDuration = animationDuration / Double(animationSteps)
                                let delta = nowFraction - start
                                for step in 1...animationSteps {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                                        let progress = Double(step) / Double(animationSteps)
                                        withAnimation(.linear(duration: stepDuration)) {
                                            selectedFraction = start + delta * progress
                                        }
                                        if step == animationSteps {
                                            selectedFraction = nil
                                        }
                                    }
                                }
                            }
                    )
                }
            }
            .frame(height: chartHeight + 2*chartPadding - 8)
            // Notification threshold and slider
            VStack(spacing: 8) {
                HStack {
                    Text("Notification Threshold:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(getChartColor(for: userThreshold).opacity(0.9))
                    Text("UV \(userThreshold)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(getChartColor(for: userThreshold))
                }
                // Time to Burn Estimate (moved above slider)
                Text("Time to Burn at this threshold: ~\(getTimeToBurnString(for: userThreshold))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(getChartColor(for: userThreshold).opacity(0.8))
                ZStack {
                    Slider(value: Binding(
                        get: { Double(userThreshold) },
                        set: { newValue in
                            userThreshold = Int(newValue.rounded())
                            UserDefaults.standard.set(userThreshold, forKey: "uvUserThreshold")
                        }
                    ), in: 1...11, step: 1)
                    .accentColor(.red)
                    GeometryReader { geo in
                        let sliderWidth = geo.size.width
                        let fraction = CGFloat(userThreshold - 1) / 10.0 // 1...11 mapped to 0...1
                        let x = fraction * (sliderWidth - 36) + 18 // Center the thumb
                        CustomSliderThumb()
                            .position(x: x, y: geo.size.height / 2)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 36)
            }
            .padding(.top, 8)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Helper Functions
    private func getChartUVData() -> [(fraction: CGFloat, uv: Int, date: Date)] {
        let calendar = Calendar.current
        let usedData: [UVData]
        if let data = data {
            usedData = data
        } else {
            // Use hourly forecast data for today
            let today = Date()
            let todayHourlyData = weatherViewModel.hourlyUVData.filter { calendar.isDate($0.date, inSameDayAs: today) }
            usedData = todayHourlyData
    
        }
        

        
        guard let first = usedData.first, let last = usedData.last else { 
    
            return [] 
        }
        
        let totalSeconds = last.date.timeIntervalSince(first.date)
        let result = usedData.map { d in
            let fraction = CGFloat(d.date.timeIntervalSince(first.date) / totalSeconds)
            return (fraction, d.uvIndex, d.date)
        }
        

        return result
    }
    private func getNowFraction() -> CGFloat {
        let uvData = getChartUVData()
        guard let first = uvData.first, let last = uvData.last else { return 0 }
        let totalSeconds = last.date.timeIntervalSince(first.date)
        let nowSeconds = currentTime.timeIntervalSince(first.date)
        return CGFloat(min(max(nowSeconds / totalSeconds, 0), 1))
    }
    private func getDisplayTimeUV() -> (String, Int?, Color) {
        let uvData = getChartUVData()

        guard uvData.count > 1 else { 

            return ("--", nil, .gray) 
        }
        
        if isDragging {
            // When dragging, interpolate the selected time and UV value
            let fraction = selectedFraction ?? getNowFraction()
            let idx = fraction * CGFloat(uvData.count - 1)
            let lowerIdx = Int(floor(idx))
            let upperIdx = min(lowerIdx + 1, uvData.count - 1)
            let interpolationFactor = idx - CGFloat(lowerIdx)
            let lowerDate = uvData[lowerIdx].date
            let upperDate = uvData[upperIdx].date
            let interpolatedTime = lowerDate.addingTimeInterval(
                (upperDate.timeIntervalSince(lowerDate)) * Double(interpolationFactor)
            )
            let lowerUV = uvData[lowerIdx].uv
            let upperUV = uvData[upperIdx].uv
            let interpolatedUV = Int(round(CGFloat(lowerUV) * (1 - interpolationFactor) + CGFloat(upperUV) * interpolationFactor))
            let color = getChartColor(for: interpolatedUV)
            let time = formatHour(interpolatedTime)
            return (time, interpolatedUV, color)
        } else {
            // When not dragging, show the actual current time
            let time = formatHour(currentTime)
            // Find the UV value at the current time by interpolating between data points
            let fraction = getNowFraction()
            let idx = fraction * CGFloat(uvData.count - 1)
            let lowerIdx = Int(floor(idx))
            let upperIdx = min(lowerIdx + 1, uvData.count - 1)
            let interpolationFactor = idx - CGFloat(lowerIdx)
            let lowerUV = uvData[lowerIdx].uv
            let upperUV = uvData[upperIdx].uv
            let interpolatedUV = Int(round(CGFloat(lowerUV) * (1 - interpolationFactor) + CGFloat(upperUV) * interpolationFactor))
            let color = getChartColor(for: interpolatedUV)
            return (time, interpolatedUV, color)
        }
    }
    private func getChartColor(for uvIndex: Int) -> Color {
        UVColorUtils.getUVColor(uvIndex)
    }
    private func formatHour(_ date: Date) -> String {
        UVColorUtils.formatHour(date)
    }
    private func getTimeToBurnString(for uv: Int) -> String {
        return UnitConverter.shared.formatTimeToBurn(uv)
    }
    private func getSelectedUV() -> Int {
        let uvData = getChartUVData()
        guard uvData.count > 1 else { return 0 }
        
        if isDragging {
            // When dragging, use the selected point
            let fraction = selectedFraction ?? getNowFraction()
            let idx = Int(round(fraction * CGFloat(uvData.count - 1)))
            let point = uvData[min(max(idx, 0), uvData.count - 1)]
            return point.uv
        } else {
            // When not dragging, interpolate UV for current time
            let fraction = getNowFraction()
            let idx = fraction * CGFloat(uvData.count - 1)
            let lowerIdx = Int(floor(idx))
            let upperIdx = min(lowerIdx + 1, uvData.count - 1)
            let interpolationFactor = idx - CGFloat(lowerIdx)
            
            let lowerUV = uvData[lowerIdx].uv
            let upperUV = uvData[upperIdx].uv
            let interpolatedUV = Int(round(CGFloat(lowerUV) * (1 - interpolationFactor) + CGFloat(upperUV) * interpolationFactor))
            
            return interpolatedUV
        }
    }
    private func catmullRomSpline(points: [CGPoint], granularity: Int = 12) -> Path {
        guard points.count > 3 else {
            var path = Path()
            if let first = points.first {
                path.move(to: first)
                for pt in points.dropFirst() { path.addLine(to: pt) }
            }
            return path
        }
        var path = Path()
        let n = points.count
        let pts = [points[0]] + points + [points[n-1]]
        path.move(to: points[0])
        for i in 1..<n {
            let p0 = pts[i-1], p1 = pts[i], p2 = pts[i+1], p3 = pts[i+2]
            for j in 1...granularity {
                let t = CGFloat(j) / CGFloat(granularity)
                let tt = t * t
                let ttt = tt * t
                let x = 0.5 * ((2 * p1.x) +
                    (-p0.x + p2.x) * t +
                    (2*p0.x - 5*p1.x + 4*p2.x - p3.x) * tt +
                    (-p0.x + 3*p1.x - 3*p2.x + p3.x) * ttt)
                let y = 0.5 * ((2 * p1.y) +
                    (-p0.y + p2.y) * t +
                    (2*p0.y - 5*p1.y + 4*p2.y - p3.y) * tt +
                    (-p0.y + 3*p1.y - 3*p2.y + p3.y) * ttt)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
    // Helper to get all contiguous time ranges where UV > threshold
    private func getUVAboveThresholdRanges() -> [(String, String)] {
        let uvData = getChartUVData()
        guard uvData.count > 1 else { return [] }
        var ranges: [(Date, Date)] = []
        var currentStart: Date? = nil
        for i in 0..<uvData.count {
            let uv = uvData[i].uv
            let date = uvData[i].date
            if uv > userThreshold {
                if currentStart == nil { currentStart = date }
            } else {
                if let start = currentStart {
                    ranges.append((start, date))
                    currentStart = nil
                }
            }
        }
        // If the last range goes to the end
        if let start = currentStart {
            ranges.append((start, uvData.last!.date))
        }
        // Format as strings
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return ranges.map { (start, end) in
            (formatter.string(from: start), formatter.string(from: end))
        }
    }
}