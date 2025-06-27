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
        
        return (dayName, date)
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
        ScrollView {
            LazyVStack(spacing: 24) {
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
            .padding(.top)
        }
        .navigationTitle("7-Day UV Forecast")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await weatherViewModel.refreshData()
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
    
    private func getAverageTimeToBurnForRanges(_ ranges: [(String, String)]) -> String {
        guard !ranges.isEmpty else { return "N/A" }
        
        // Calculate average UV during danger periods
        var totalUV = 0
        var count = 0
        
        for range in ranges {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            
            // Find UV data points within this range
            for uvPoint in uvData {
                let timeString = formatter.string(from: uvPoint.date)
                if timeString >= range.0 && timeString <= range.1 {
                    totalUV += uvPoint.uvIndex
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return "N/A" }
        let averageUV = totalUV / count
        return "~\(UVColorUtils.calculateTimeToBurn(uvIndex: averageUV)) min"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Peak UV Display (Left side - prominent)
            VStack(spacing: 4) {
                Text("\(getMaxUV())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(UVColorUtils.getUVColor(getMaxUV()))
                Text("Peak UV")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text("~\(UVColorUtils.calculateTimeToBurn(uvIndex: getMaxUV())) min")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .center)
            
            // Day and UV Details (Right side)
            VStack(alignment: .leading, spacing: 8) {
                // Day header
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayInfo.dayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(dayInfo.date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !uvData.isEmpty {
                    // Peak time
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .font(.system(size: 12, weight: .medium))
                        Text("Peak at \(getPeakUVTime())")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    // Danger zones or safe status
                    let warningRanges = getUVAboveThresholdRanges()
                    if !warningRanges.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12, weight: .medium))
                                Text("Avoid UV (Above \(userThreshold))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            // Average burn time for all danger periods
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .foregroundColor(.red)
                                    .font(.system(size: 10, weight: .medium))
                                Text("Average burn time: \(getAverageTimeToBurnForRanges(warningRanges))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            
                            ForEach(Array(warningRanges.enumerated()), id: \.offset) { index, range in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("\(range.0) – \(range.1)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("~\(UVColorUtils.calculateTimeToBurn(uvIndex: getMaxUV())) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                    } else {
                        // Safe day
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12, weight: .medium))
                            Text("UV below threshold - Safe for outdoor activities")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.green.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        )
                    }
                } else {
                    // No data available
                    Text("No UV data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(UVColorUtils.getUVColor(getMaxUV()).opacity(0.08))
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
} 