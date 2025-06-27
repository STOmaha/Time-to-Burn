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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayInfo.dayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(dayInfo.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Max UV")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(getMaxUV())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(UVColorUtils.getUVColor(getMaxUV()))
                }
            }
            
            // UV Color Bar
            if !uvData.isEmpty {
                UVColorBar(uvData: uvData, userThreshold: userThreshold)
                    .frame(height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Time labels
                HStack {
                    Text("12am")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("12pm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("12am")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Warning ranges
                let warningRanges = getUVAboveThresholdRanges()
                if !warningRanges.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(warningRanges.enumerated()), id: \.offset) { index, range in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 10, weight: .medium))
                                Text("Avoid UV Between: \(range.0) – \(range.1)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // No data available
                HStack {
                    Spacer()
                    Text("No UV data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}

struct UVColorBar: View {
    let uvData: [UVData]
    let userThreshold: Int
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: uvData.map { UVColorUtils.getUVColor($0.uvIndex) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Danger zone overlay
                ForEach(0..<uvData.count-1, id: \.self) { i in
                    let current = uvData[i]
                    let next = uvData[i+1]
                    
                    if current.uvIndex > userThreshold || next.uvIndex > userThreshold {
                        let startX = geo.size.width * CGFloat(i) / CGFloat(uvData.count - 1)
                        let endX = geo.size.width * CGFloat(i + 1) / CGFloat(uvData.count - 1)
                        
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: endX - startX)
                            .offset(x: startX)
                    }
                }
            }
        }
    }
} 