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
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background gradient based on UV Index
                LinearGradient(
                    gradient: Gradient(colors: [darkerUVColor, darkerUVColor.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if weatherViewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView("Loading UV data...")
                            .scaleEffect(1.5)
                        Text("Please ensure location services are enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = weatherViewModel.error {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Error loading UV data")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                locationManager.requestLocation()
                                await weatherViewModel.refreshData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Location and UV Index Card
                            UVIndexCard(
                                location: locationManager.locationName,
                                uvData: weatherViewModel.currentUVData,
                                currentTime: currentTime,
                                lastUpdated: weatherViewModel.lastUpdated
                            )
                            
                            // UV Chart
                            UVChartView()
                        }
                        .padding()
                    }
                    .refreshable {
                        locationManager.requestLocation()
                        await weatherViewModel.refreshData()
                    }
                }
                
                // Notification Bell Button
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            showingNotifications = true
                        }) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationSettingsView()
                    .environmentObject(notificationService)
            }
            .task {
                locationManager.requestLocation()
                await weatherViewModel.refreshData()
            }
            .onReceive(timer) { input in
                currentTime = input
            }
            .navigationBarHidden(true)
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

