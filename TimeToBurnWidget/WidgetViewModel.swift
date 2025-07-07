import SwiftUI
import WidgetKit

@MainActor
class WidgetViewModel: ObservableObject {
    @Published var sharedData: SharedUVData?
    @Published var hourlyUVData: [UVData] = []
    
    init() {
        loadData()
    }
    
    func loadData() {
        sharedData = SharedDataManager.shared.loadSharedData()
        // For now, we'll use mock hourly data for the chart
        // In a real implementation, this would come from the main app's shared data
        hourlyUVData = generateMockHourlyData()
    }
    
    private func generateMockHourlyData() -> [UVData] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var data: [UVData] = []
        for hour in 6...20 { // 6 AM to 8 PM
            guard let date = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
            
            // Generate realistic UV data (peak around noon)
            let hourOfDay = calendar.component(.hour, from: date)
            let uvIndex: Int
            if hourOfDay < 10 || hourOfDay > 16 {
                uvIndex = Int.random(in: 1...3)
            } else if hourOfDay == 12 || hourOfDay == 13 {
                uvIndex = Int.random(in: 8...11)
            } else {
                uvIndex = Int.random(in: 4...7)
            }
            
            data.append(UVData(uvIndex: uvIndex, date: date))
        }
        return data
    }
    
    func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0:
            return .gray
        case 1...2:
            return .green
        case 3...5:
            return .yellow
        case 6...7:
            return .orange
        case 8...10:
            return .red
        case 11...:
            return .purple
        default:
            return .gray
        }
    }
    
    func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    func getTimeToBurnText(_ timeToBurn: Int?) -> String {
        guard let timeToBurn = timeToBurn, timeToBurn > 0 else {
            return "∞"
        }
        // Convert seconds to minutes
        let minutes = timeToBurn / 60
        return "\(minutes) min"
    }
    
    func getChartUVData() -> [(fraction: CGFloat, uv: Int, date: Date)] {
        guard hourlyUVData.count > 1 else { return [] }
        
        let first = hourlyUVData.first!
        let last = hourlyUVData.last!
        let totalSeconds = last.date.timeIntervalSince(first.date)
        
        return hourlyUVData.map { data in
            let fraction = CGFloat(data.date.timeIntervalSince(first.date) / totalSeconds)
            return (fraction, data.uvIndex, data.date)
        }
    }
} 