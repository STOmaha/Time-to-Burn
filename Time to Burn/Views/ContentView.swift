import SwiftUI
import Charts
import WeatherKit
import CoreLocation

struct UVLineContent: ChartContent {
    let data: UVData
    
    var body: some ChartContent {
        LineMark(
            x: .value("Time", data.date),
            y: .value("UV Index", Double(data.uvIndex))
        )
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .foregroundStyle(
            LinearGradient(
                colors: [.purple, .red, .orange, .yellow, .green],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct UVAreaContent: ChartContent {
    let data: UVData
    
    var body: some ChartContent {
        AreaMark(
            x: .value("Time", data.date),
            y: .value("UV Index", Double(data.uvIndex))
        )
        .interpolationMethod(.catmullRom)
        .foregroundStyle(
            LinearGradient(
                colors: [
                    getChartColor(for: data.uvIndex).opacity(0.3),
                    getChartColor(for: data.uvIndex).opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
}

struct UVPointContent: ChartContent {
    let data: UVData
    
    var body: some ChartContent {
        PointMark(
            x: .value("Time", data.date),
            y: .value("UV Index", Double(data.uvIndex))
        )
        .foregroundStyle(getChartColor(for: data.uvIndex))
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
}

struct UVDangerZoneContent: ChartContent {
    let data: UVData
    let threshold: Int
    
    var body: some ChartContent {
        RectangleMark(
            xStart: .value("Start", data.date.addingTimeInterval(-1800)), // 30 min before
            xEnd: .value("End", data.date.addingTimeInterval(1800)),      // 30 min after
            yStart: .value("Threshold", Double(threshold)),
            yEnd: .value("Max", 12.0)
        )
        .foregroundStyle(Color.red.opacity(0.15))
        .opacity(data.uvIndex >= threshold ? 1 : 0)
    }
}

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
                NotificationCard()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .task {
                print("ContentView: Initial task started")
                locationManager.requestLocation()
                if let location = locationManager.location {
                    print("ContentView: Location available, fetching UV data")
                    await weatherViewModel.fetchUVData(for: location)
                } else {
                    print("ContentView: No location available")
                }
            }
            .onChange(of: locationManager.location) { oldValue, newValue in
                print("ContentView: Location changed")
                if let location = newValue {
                    Task {
                        await weatherViewModel.fetchUVData(for: location)
                    }
                }
            }
            .onReceive(timer) { time in
                currentTime = time
            }
        }
    }
    
    // Add computed property for dynamic background color
    private var darkerUVColor: Color {
        guard let uvIndex = weatherViewModel.currentUVData?.uvIndex else {
            return Color.blue.opacity(0.7)
        }
        switch uvIndex {
        case 0: return Color.blue.darken()
        case 1...2: return Color.green.darken()
        case 3...5: return Color.yellow.darken()
        case 6...7: return Color.orange.darken()
        case 8...10: return Color.red.darken()
        case 11: return Color.purple.darken()
        case 12: return Color.black.darken()
        default: return Color.black.darken()
        }
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let timeString = formatter.string(from: date)
        
        let amPmFormatter = DateFormatter()
        amPmFormatter.dateFormat = "a"
        let amPm = amPmFormatter.string(from: date).lowercased()
        
        return "\(timeString)\(amPm)"
    }
    
    private func formatKeyTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Show 12am at start and end
        if hour == 0 {
            return "12am"
        }
        
        // Show 12pm at noon
        if hour == 12 {
            return "12pm"
        }
        
        // Show "Now" for current hour
        let currentHour = calendar.component(.hour, from: currentTime)
        if hour == currentHour {
            return "Now"
        }
        
        // Show threshold times if they exist
        if isThresholdTime(date) {
            return formatHour(date)
        }
        
        // For other times, show a simplified format
        if hour < 12 {
            return "\(hour)am"
        } else if hour == 12 {
            return "12pm"
        } else {
            return "\(hour - 12)pm"
        }
    }
    
    private func isThresholdTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Check if this hour has UV crossing the threshold
        let threshold = notificationService.uvAlertThreshold
        
        // Find the UV data for this hour
        if let uvData = weatherViewModel.hourlyForecast.first(where: { 
            calendar.component(.hour, from: $0.date) == hour 
        }) {
            // Show if UV is at or above threshold
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
                        UVDangerZoneContent(data: data, threshold: notificationService.uvAlertThreshold)
                        
                        // Existing Layers
                        UVAreaContent(data: data)
                        UVLineContent(data: data)
                        // UVPointContent(data: data) // Removed to hide plot points
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
                .chartYScale(domain: 0...max(12, Double(weatherViewModel.hourlyForecast.map { $0.uvIndex }.max() ?? 12)))
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
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
        
        // Find all hours where UV is at or above threshold
        let highUVHours = weatherViewModel.hourlyForecast.enumerated().compactMap { index, data in
            data.uvIndex >= threshold ? index : nil
        }
        
        guard !highUVHours.isEmpty else {
            return nil // No high UV periods
        }
        
        // Group consecutive hours into ranges
        var ranges: [(start: Int, end: Int)] = []
        var currentStart = highUVHours[0]
        var currentEnd = highUVHours[0]
        
        for i in 1..<highUVHours.count {
            if highUVHours[i] == currentEnd + 1 {
                currentEnd = highUVHours[i]
            } else {
                ranges.append((start: currentStart, end: currentEnd))
                currentStart = highUVHours[i]
                currentEnd = highUVHours[i]
            }
        }
        ranges.append((start: currentStart, end: currentEnd))
        
        // Format the ranges
        let rangeStrings = ranges.map { range in
            let startHour = range.start
            let endHour = range.end
            
            let startTime = formatTimeForHour(startHour)
            let endTime = formatTimeForHour(endHour + 1) // Add 1 to show end time
            
            if startHour == endHour {
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
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
}

struct NotificationCard: View {
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notifications")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    NotificationRow(
                        title: "High UV Alerts",
                        description: "Get notified when UV index is high",
                        isEnabled: $notificationService.isHighUVAlertsEnabled
                    )
                    if notificationService.isHighUVAlertsEnabled {
                        HStack {
                            Text("Alert Threshold: ")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { Double(notificationService.uvAlertThreshold) },
                                set: { newValue in
                                    let intValue = Int(newValue.rounded())
                                    notificationService.uvAlertThreshold = intValue
                                    notificationService.updateNotificationPreferences(
                                        highUVAlerts: notificationService.isHighUVAlertsEnabled,
                                        dailyUpdates: notificationService.isDailyUpdatesEnabled,
                                        locationChanges: notificationService.isLocationChangesEnabled,
                                        uvAlertThreshold: intValue
                                    )
                                }
                            ), in: 1...12, step: 1)
                            .frame(maxWidth: 150)
                            Text("\(notificationService.uvAlertThreshold)")
                                .font(.subheadline)
                                .frame(width: 28)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                NotificationRow(
                    title: "Daily Updates",
                    description: "Receive daily UV index updates",
                    isEnabled: $notificationService.isDailyUpdatesEnabled
                )
                NotificationRow(
                    title: "Location Changes",
                    description: "Get notified when you enter a new area",
                    isEnabled: $notificationService.isLocationChangesEnabled
                )
            }
            .onChange(of: notificationService.isHighUVAlertsEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            .onChange(of: notificationService.isDailyUpdatesEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            .onChange(of: notificationService.isLocationChangesEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            
            // Debug/Test Button
            Button(action: {
                notificationService.testHighUVNotification()
            }) {
                Label("Test High UV Notification", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            .accessibilityIdentifier("TestHighUVNotificationButton")
            
            // Manual Background Check Button
            Button(action: {
                notificationService.triggerBackgroundUVCheck()
            }) {
                Label("Trigger Background UV Check", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top, 5)
            .accessibilityIdentifier("TriggerBackgroundCheckButton")
            
            Spacer()
        }
        .padding()
    }
    
    private func updateNotificationPreferences() {
        notificationService.updateNotificationPreferences(
            highUVAlerts: notificationService.isHighUVAlertsEnabled,
            dailyUpdates: notificationService.isDailyUpdatesEnabled,
            locationChanges: notificationService.isLocationChangesEnabled,
            uvAlertThreshold: notificationService.uvAlertThreshold
        )
    }
}

struct NotificationRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct UVIndexCard: View {
    let location: String
    let uvData: UVData?
    let currentTime: Date
    let lastUpdated: Date?
    
    var body: some View {
        VStack(spacing: 15) {
            Text(location)
                .font(.title2)
                .fontWeight(.medium)
            
            if let uvData = uvData {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    Text(uvIndexDisplay(uvData.uvIndex))
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.black)
                        .opacity(0.25)
                        .overlay(
                            Text(uvIndexDisplay(uvData.uvIndex))
                                .font(.system(size: 72, weight: .bold))
                                .foregroundColor(uvIndexColor(uvData.uvIndex))
                                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                        )
                }
                
                Text(uvData.uvIndex == 12 ? "<5 minutes to burn" : 
                     uvData.uvIndex == 0 ? "∞ minutes to burn" :
                     "\(uvData.timeToBurn ?? UVData.calculateTimeToBurn(uvIndex: uvData.uvIndex)) minutes to burn")
                    .font(uvData.uvIndex >= 6 ? .title2 : .subheadline)
                    .fontWeight(uvData.uvIndex >= 6 ? .bold : .regular)
                    .foregroundColor(uvData.uvIndex >= 6 ? .red : .secondary)
                    .padding(.top, 2)
                
                // Last Updated Time
                if let lastUpdated = lastUpdated {
                    Text("Last updated: \(timeAgoString(from: lastUpdated, to: currentTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Protection Advice")
                        .font(.headline)
                    Text(uvData.advice ?? UVData.getAdvice(uvIndex: uvData.uvIndex))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func uvIndexColor(_ index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        case 11: return .purple
        case 12: return .black
        default: return .black
        }
    }
    
    private func uvIndexDisplay(_ index: Int) -> String {
        return "\(index)"
    }
    
    private func timeAgoString(from date: Date, to now: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour], from: date, to: now)
        if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute {
            if minute == 0 {
                return "Just now"
            }
            return "\(minute)m ago"
        }
        return "Just now"
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(WeatherViewModel(notificationService: NotificationService.shared))
}

extension ContentView {
    func timeAgoString(from date: Date, to now: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour], from: date, to: now)
        if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute {
            if minute == 0 {
                return "Just now"
            }
            return "\(minute)m ago"
        }
        return "Just now"
    }
}

// Add Color extension for darken
extension Color {
    func darken(amount: Double = 0.5) -> Color {
        return self.opacity(1.0 - amount)
    }
} 
