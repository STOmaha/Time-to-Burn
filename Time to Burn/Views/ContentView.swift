import SwiftUI
import Charts
import WeatherKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var showingNotifications = false
    @State private var currentTime = Date()
    @State private var showingUVChart = false
    @State private var selectedTime = Date()
    @State private var isDragging = false
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        // 6am = 0, noon = 0.25, 6pm = 0.5, midnight = 0.75
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        return offsetSeconds / (24*3600)
    }
    
    private func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
        let rectWidth = geo.size.width * 0.92
        let rectHeight = geo.size.height * 0.92
        let cornerRadius = min(rectWidth, rectHeight) * 0.18
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2
        let halfWidth = rectWidth / 2
        let halfHeight = rectHeight / 2
        
        // Calculate the perimeter length to map time to position
        let straightLength = 2 * (rectWidth + rectHeight - 2 * cornerRadius)
        let cornerLength = 2 * .pi * cornerRadius
        let totalPerimeter = straightLength + cornerLength
        
        // Map time (0-1) to distance along perimeter
        // 6am = 0, noon = 0.25, 6pm = 0.5, midnight = 0.75
        let distance = t * totalPerimeter
        
        // Determine which segment we're on and calculate position
        var currentDistance = 0.0
        
        // Left edge (6am position - bottom to top)
        let leftEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + leftEdgeLength {
            let progress = (distance - currentDistance) / leftEdgeLength
            let x = centerX - halfWidth
            let y = centerY + halfHeight - cornerRadius - progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += leftEdgeLength
        
        // Top-left corner
        let cornerArcLength = .pi * cornerRadius / 2
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * sin(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Top edge (noon position - left to right)
        let topEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + topEdgeLength {
            let progress = (distance - currentDistance) / topEdgeLength
            let x = centerX - halfWidth + cornerRadius + progress * (rectWidth - 2 * cornerRadius)
            let y = centerY - halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += topEdgeLength
        
        // Top-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * cos(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Right edge (6pm position - top to bottom)
        let rightEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + rightEdgeLength {
            let progress = (distance - currentDistance) / rightEdgeLength
            let x = centerX + halfWidth
            let y = centerY - halfHeight + cornerRadius + progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += rightEdgeLength
        
        // Bottom-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * sin(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Bottom edge (midnight position - right to left)
        let bottomEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + bottomEdgeLength {
            let progress = (distance - currentDistance) / bottomEdgeLength
            let x = centerX + halfWidth - cornerRadius - progress * (rectWidth - 2 * cornerRadius)
            let y = centerY + halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += bottomEdgeLength
        
        // Bottom-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * cos(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        
        // Fallback to left edge (6am position)
        return CGPoint(x: centerX - halfWidth, y: centerY)
    }
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                let now = timeline.date
                let sunT = timeFraction(for: now)
                let moonT = (sunT + 0.5).truncatingRemainder(dividingBy: 1.0)
                let sunPos = positionOnPerimeter(t: sunT, geo: geo)
                let moonPos = positionOnPerimeter(t: moonT, geo: geo)
                let rectWidth = geo.size.width * 0.92
                let rectHeight = geo.size.height * 0.92
                let rectCorner = min(rectWidth, rectHeight) * 0.18
                ZStack {
                    RoundedRectangle(cornerRadius: rectCorner)
                        .stroke(Color.yellow.opacity(0.7), lineWidth: 6)
                        .frame(width: rectWidth, height: rectHeight)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    
                    // Time labels
                    Text("6am")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: geo.size.width / 2 - rectWidth / 2, y: geo.size.height / 2)
                    
                    Text("Noon")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - rectHeight / 2)
                    
                    Text("6pm")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: geo.size.width / 2 + rectWidth / 2, y: geo.size.height / 2)
                    
                    Text("Midnight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + rectHeight / 2)
                    
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                        .position(sunPos)
                        .shadow(radius: 10)
                        .animation(.easeInOut(duration: 0.8), value: sunPos)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue.opacity(0.8))
                        .position(moonPos)
                        .shadow(radius: 8)
                        .animation(.easeInOut(duration: 0.8), value: moonPos)
                    
                    // Sunrise marker
                    if let sunrise = weatherViewModel.sunrise {
                        let sunriseT = timeFraction(for: sunrise)
                        let sunrisePos = positionOnPerimeter(t: sunriseT, geo: geo)
                        VStack(spacing: 2) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                                .shadow(radius: 4)
                            Text(sunrise, style: .time)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .position(sunrisePos)
                    }
                    
                    // Sunset marker
                    if let sunset = weatherViewModel.sunset {
                        let sunsetT = timeFraction(for: sunset)
                        let sunsetPos = positionOnPerimeter(t: sunsetT, geo: geo)
                        VStack(spacing: 2) {
                            Image(systemName: "sunset.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.pink)
                                .shadow(radius: 4)
                            Text(sunset, style: .time)
                                .font(.caption)
                                .foregroundColor(.pink)
                        }
                        .position(sunsetPos)
                    }
                    
                    // Moonrise marker
                    if let moonrise = weatherViewModel.moonrise {
                        let moonriseT = timeFraction(for: moonrise)
                        let moonrisePos = positionOnPerimeter(t: moonriseT, geo: geo)
                        VStack(spacing: 2) {
                            Image(systemName: "moonrise.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.cyan)
                                .shadow(radius: 4)
                            Text(moonrise, style: .time)
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                        .position(moonrisePos)
                    }
                    
                    // Moonset marker
                    if let moonset = weatherViewModel.moonset {
                        let moonsetT = timeFraction(for: moonset)
                        let moonsetPos = positionOnPerimeter(t: moonsetT, geo: geo)
                        VStack(spacing: 2) {
                            Image(systemName: "moonset.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.indigo)
                                .shadow(radius: 4)
                            Text(moonset, style: .time)
                                .font(.caption2)
                                .foregroundColor(.indigo)
                        }
                        .position(moonsetPos)
                    }
                    
                    // Loading indicator if no data available
                    if weatherViewModel.sunrise == nil && weatherViewModel.sunset == nil && 
                       weatherViewModel.moonrise == nil && weatherViewModel.moonset == nil {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .foregroundColor(.white)
                            Text("Loading astronomical data...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                }
                .background(Color.black.ignoresSafeArea())
            }
        }
    }
    
    // MARK: - Computed Properties
    private var darkerUVColor: Color {
        if let uvIndex = weatherViewModel.currentUVData?.uvIndex {
            return getUVColor(uvIndex)
        }
        return .blue
    }
    
    // MARK: - UI Helper Functions
    private func getUVCategory(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatKeyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date).lowercased()
    }
    
    private func isHighUV(at time: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        if let uvData = weatherViewModel.hourlyForecast.first(where: { calendar.component(.hour, from: $0.date) == hour }) {
            let threshold = notificationService.uvAlertThreshold
            return uvData.uvIndex >= threshold
        }
        
        return false
    }
    
    private func getChartColor(for uvIndex: Int) -> Color {
        switch uvIndex {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    private func legendItem(color: Color, range: String, label: String) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(range)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Chart Components
    private func UVChartView() -> some View {
        VStack(spacing: 16) {
            
            // UV Exposure Warning
            if let warningText = getUVExposureWarning() {
                Text(warningText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Current Time Indicator
            HStack {
                Text(isDragging ? "Selected:" : "Now:")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(formatHour(isDragging ? selectedTime : currentTime))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if isDragging, let uvLevel = getUVLevelForTime(selectedTime) {
                    Text("• UV \(uvLevel)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(getUVColor(uvLevel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack(alignment: .bottom) {
                // Chart Area
                Chart {
                    ForEach(weatherViewModel.hourlyForecast) { data in
                        // Danger Zone Layer
                        if data.uvIndex >= notificationService.uvAlertThreshold {
                            RectangleMark(
                                xStart: .value("Start", data.date.addingTimeInterval(-1800)), // 30 min before
                                xEnd: .value("End", data.date.addingTimeInterval(1800)),      // 30 min after
                                yStart: .value("Threshold", Double(notificationService.uvAlertThreshold)),
                                yEnd: .value("Max", 12.0)
                            )
                            .foregroundStyle(Color.red.opacity(0.15))
                        }
                        
                        // Area Mark
                        AreaMark(
                            x: .value("Time", data.date),
                            y: .value("UV Index", Double(data.uvIndex))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .green.opacity(0.3), .yellow.opacity(0.3), .orange.opacity(0.3), .red.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        
                        // Line Mark
                        LineMark(
                            x: .value("Time", data.date),
                            y: .value("UV Index", Double(data.uvIndex))
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .green, .yellow, .orange, .red, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                    
                    // Threshold Line
                    RuleMark(
                        y: .value("UV Threshold", Double(notificationService.uvAlertThreshold))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.red)
                    .annotation(position: .top, alignment: .leading, spacing: 0) {
                        Text("UV Threshold")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                            .offset(y: 9)
                    }
                    
                    // Interactive Time Line (shows selected time when dragging, current time otherwise)
                    RuleMark(
                        x: .value("Selected Time", isDragging ? selectedTime : currentTime)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(.blue)
                }
                .chartXScale(domain: Calendar.current.startOfDay(for: Date())...Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600))
                .chartYScale(domain: -0.5...max(12, Double(weatherViewModel.hourlyForecast.map { $0.uvIndex }.max() ?? 12)))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatKeyTime(date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self), intValue >= 0 {
                                Text("\(intValue)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let location = value.location
                                        if let date: Date = proxy.value(atX: location.x) {
                                            selectedTime = date
                                        }
                                    }
                                    .onEnded { _ in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            withAnimation {
                                                isDragging = false
                                            }
                                        }
                                    }
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func getUVExposureWarning() -> String? {
        let threshold = notificationService.uvAlertThreshold
        
        let highUVDataPoints = weatherViewModel.hourlyForecast.filter { $0.uvIndex >= threshold }
        
        guard !highUVDataPoints.isEmpty else { return nil }
        
        // Group consecutive hours
        var ranges: [[UVData]] = []
        var currentRange: [UVData] = []
        
        for dataPoint in highUVDataPoints {
            if let lastDataPoint = currentRange.last, dataPoint.date.timeIntervalSince(lastDataPoint.date) > (30 * 60 + 1) { // Greater than 31 mins apart
                ranges.append(currentRange)
                currentRange = [dataPoint]
            } else {
                currentRange.append(dataPoint)
            }
        }
        if !currentRange.isEmpty {
            ranges.append(currentRange)
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h a" // e.g., "9 AM"
        
        let rangeStrings = ranges.map { range in
            guard let first = range.first, let last = range.last else { return "" }
            
            let startTime = timeFormatter.string(from: first.date)
            let endTime = timeFormatter.string(from: last.date.addingTimeInterval(30*60)) // End of the last half-hour block
            
            if first.date == last.date {
                return startTime
            } else {
                return "\(startTime)-\(endTime)"
            }
        }
        
        return "Avoid UV exposure: \(rangeStrings.joined(separator: ", "))"
    }
    
    private func formatTimeForHour(_ hour: Int) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: targetDate).lowercased()
    }
    
    private func getUVLevelForTime(_ time: Date) -> Int? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        // Find the UV data for this hour
        if let uvData = weatherViewModel.hourlyForecast.first(where: { 
            calendar.component(.hour, from: $0.date) == hour 
        }) {
            return uvData.uvIndex
        }
        
        return nil
    }
    
    private func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0: return .blue
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
}

struct UVIndexCard: View {
    var location: String
    var uvData: UVData?
    var currentTime: Date
    var lastUpdated: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UV Index Forecast")
            // Location and Last Updated
            HStack {
                Image(systemName: "location.fill")
                Text(location)
                    .font(.headline)
                Spacer()
                if let lastUpdated = lastUpdated {
                    Text("Updated \(lastUpdated, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Main UV Index Display
            if let uvData = uvData {
                HStack(alignment: .center, spacing: 20) {
                    VStack {
                        Text("\(uvData.uvIndex)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(getUVColor(uvData.uvIndex))
                        Text(getUVCategory(for: uvData.uvIndex))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(getUVColor(uvData.uvIndex))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("Time to Burn:")
                        }
                        .font(.headline)
                        
                        let minutesToBurn = SunExposureCalculator.minutesToBurn(uvIndex: Double(uvData.uvIndex))
                        
                        if minutesToBurn.isInfinite {
                            Text("∞ minutes")
                                .font(.title)
                                .fontWeight(.semibold)
                        } else {
                            Text("~\(Int(minutesToBurn)) minutes")
                                .font(.title)
                                .fontWeight(.semibold)
                        }
                        
                        Text(getUVAdvice(for: uvData.uvIndex))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No UV data available")
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0: return .blue
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    private func getUVCategory(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    private func getUVAdvice(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2:
            return "No protection needed. You can safely stay outside."
        case 3...5:
            return "Moderate risk of harm. Wear sunscreen, protective clothing, and seek shade during midday hours."
        case 6...7:
            return "High risk of harm. Seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses."
        case 8...10:
            return "Very high risk of harm. Minimize sun exposure between 10 a.m. and 4 p.m."
        default:
            return "Extreme risk of harm. Avoid sun exposure and take all precautions."
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LocationManager())
            .environmentObject(NotificationService.shared)
            .environmentObject(WeatherViewModel(notificationService: NotificationService.shared))
    }
}

