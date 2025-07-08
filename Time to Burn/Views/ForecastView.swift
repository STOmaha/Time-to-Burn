import SwiftUI

struct ForecastView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var userThreshold: Int = UserDefaults.standard.integer(forKey: "uvUserThreshold") == 0 ? 6 : UserDefaults.standard.integer(forKey: "uvUserThreshold")
    
    private func getUVData(forDayOffset offset: Int) -> [UVData] {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { return [] }
        return weatherViewModel.hourlyUVData.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
    
    private func getDayNameAndDate(forDayOffset offset: Int) -> (dayName: String, date: String) {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { 
            return ("", "") 
        }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: day)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let date = dateFormatter.string(from: day)
        
        // Check if this is today
        let isToday = calendar.isDateInToday(day)
        let displayDayName = isToday ? "Today" : dayName
        
        return (displayDayName, date)
    }
    
    private func getMaxUV(for uvData: [UVData]) -> Int {
        return uvData.map { $0.uvIndex }.max() ?? 0
    }
    
    private func getUVAboveThresholdRanges(for uvData: [UVData]) -> [(String, String)] {
        guard uvData.count > 1 else { return [] }
        var ranges: [(Date, Date)] = []
        var currentStart: Date? = nil
        
        for i in 0..<uvData.count {
            let uv = uvData[i].uvIndex
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        DayForecastCard(
                            dayOffset: dayOffset,
                            uvData: getUVData(forDayOffset: dayOffset),
                            userThreshold: userThreshold,
                            dayInfo: getDayNameAndDate(forDayOffset: dayOffset)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("7-Day UV Forecast")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                print("📅 [ForecastView] 📊 View appeared, data should be available from shared flow")
            }
        }
    }
}

struct DayForecastCard: View {
    let dayOffset: Int
    let uvData: [UVData]
    let userThreshold: Int
    let dayInfo: (dayName: String, date: String)
    
    private func getMaxUV() -> Int {
        return uvData.map { $0.uvIndex }.max() ?? 0
    }
    
    private func getUVAboveThresholdRanges() -> [(String, String)] {
        guard uvData.count > 1 else { return [] }
        var ranges: [(Date, Date)] = []
        var currentStart: Date? = nil
        
        for i in 0..<uvData.count {
            let uv = uvData[i].uvIndex
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
        
        if let start = currentStart {
            ranges.append((start, uvData.last!.date))
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return ranges.map { (start, end) in
            (formatter.string(from: start), formatter.string(from: end))
        }
    }
    
    private func getPeakUVTime() -> String {
        guard let maxUVData = uvData.max(by: { $0.uvIndex < $1.uvIndex }) else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: maxUVData.date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with day info and peak UV
            HStack(spacing: 16) {
                // Day info (left side)
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayInfo.dayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(dayInfo.date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Peak UV display (right side)
                VStack(spacing: 4) {
                    Text("\(getMaxUV())")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(UVColorUtils.getUVColor(getMaxUV()))
                    Text("Peak UV")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Divider
            Divider()
                .padding(.horizontal, 20)
            
            // Content area
            VStack(spacing: 16) {
                if !uvData.isEmpty {
                    // Peak time info
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .medium))
                        Text("Peak at \(getPeakUVTime())")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Danger zones or safe status
                    let warningRanges = getUVAboveThresholdRanges()
                    if !warningRanges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Warning header
                            HStack(spacing: 8) {
                                Image(systemName: "shield.exclamationmark.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Avoid UV Exposure")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Above \(userThreshold)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Time ranges
                            VStack(spacing: 8) {
                                ForEach(Array(warningRanges.enumerated()), id: \.offset) { index, range in
                                    HStack(spacing: 12) {
                                        // Time range icon
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(width: 20)
                                        
                                        // Time range text
                                        Text("\(range.0) – \(range.1)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // UV level indicator
                                        Text("UV \(getMaxUV())")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(UVColorUtils.getUVColor(getMaxUV()))
                                            )
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.red.opacity(0.08))
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    } else {
                        // Safe day
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("UV Below Threshold")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Safe for outdoor activities")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                } else {
                    // No data available
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("No UV data available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(getUVBackgroundColor())
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
    
    private func getUVBackgroundColor() -> Color {
        let maxUV = getMaxUV()
        return UVColorUtils.getPastelUVColor(maxUV)
    }
} 