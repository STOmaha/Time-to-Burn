import SwiftUI
import Charts

struct UVChartView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var notificationService: NotificationService
    @State private var isDragging = false
    @State private var selectedTime = Date()
    
    var body: some View {
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
                Text(formatHour(isDragging ? selectedTime : Date()))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if isDragging, let uvLevel = getUVLevelForTime(selectedTime) {
                    Text("• UV \(uvLevel)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UVColorUtils.getUVColor(uvLevel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show the entire 24-hour period in a single view
            ZStack(alignment: .bottom) {
                ScrollView {
                    Chart {
                        chartMarks
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatKeyTime(date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                Text("\(value.as(Int.self) ?? 0)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .chartYScale(domain: 0...12)
                    .chartXScale(domain: startOfToday()...endOfToday())
                    .chartOverlay { proxy in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let location = value.location
                                        if let date = proxy.value(atX: location.x, as: Date.self) {
                                            selectedTime = date
                                        }
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                        withAnimation(.easeOut(duration: 0.6)) {
                                            selectedTime = Date()
                                        }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 220)
                }
                .refreshable {
                    await weatherViewModel.refreshData()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(20)
        .shadow(radius: 8)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    private func getUVExposureWarning() -> String? {
        guard let currentUV = weatherViewModel.currentUVData?.uvIndex else { return nil }
        
        if currentUV >= notificationService.uvAlertThreshold {
            return "⚠️ High UV exposure detected! Take precautions."
        }
        return nil
    }
    
    private func formatHour(_ date: Date) -> String {
        return UVColorUtils.formatHour(date)
    }
    
    private func formatKeyTime(_ date: Date) -> String {
        return UVColorUtils.formatKeyTime(date)
    }
    
    private func getUVLevelForTime(_ time: Date) -> Int? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        return weatherViewModel.hourlyForecast.first { 
            calendar.component(.hour, from: $0.date) == hour 
        }?.uvIndex
    }
    
    private func getChartColor(for uvIndex: Int) -> Color {
        return UVColorUtils.getUVColor(uvIndex)
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
    
    private func isToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    private func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func endOfToday() -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfToday()) ?? Date()
    }
    
    // MARK: - Chart Marks
    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        let todayData = weatherViewModel.hourlyForecast.filter { isToday($0.date) }
        // Danger Zone Layer and AreaMark per point
        ForEach(todayData) { data in
            if data.uvIndex >= notificationService.uvAlertThreshold {
                RectangleMark(
                    xStart: .value("Start", data.date.addingTimeInterval(-1800)),
                    xEnd: .value("End", data.date.addingTimeInterval(1800)),
                    yStart: .value("Threshold", Double(notificationService.uvAlertThreshold)),
                    yEnd: .value("Max", 12.0)
                )
                .foregroundStyle(Color.red.opacity(0.15))
            }
            AreaMark(
                x: .value("Time", data.date),
                y: .value("UV Index", data.uvIndex)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [getChartColor(for: data.uvIndex).opacity(0.3), getChartColor(for: data.uvIndex).opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        // Thicker, color-transitioning line for the whole day
        ForEach(todayData) { data in
            LineMark(
                x: .value("Time", data.date),
                y: .value("UV Index", data.uvIndex)
            )
            .lineStyle(StrokeStyle(lineWidth: 5))
            .foregroundStyle(getChartColor(for: data.uvIndex))
        }
        // Dashed threshold line
        RuleMark(y: .value("Threshold", notificationService.uvAlertThreshold))
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(Color.red)
            .annotation(position: .top, alignment: .leading) {
                Text("UV Threshold")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(4)
            }
        // Blue vertical bar: follows touch or animates back to now
        RuleMark(x: .value("Selected", isDragging ? selectedTime : Date()))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.blue)
    }
} 