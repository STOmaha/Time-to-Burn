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
        if let sharedData = sharedData, let hourlyData = sharedData.hourlyUVData {
            hourlyUVData = hourlyData
        } else {
            hourlyUVData = generateMockHourlyData()
        }
        
        // Debug logging
        if let sharedData = sharedData {
            let uvEmoji = getUVEmoji(sharedData.currentUVIndex)
            let timeToBurnText = sharedData.timeToBurn == Int.max ? "∞" : "\(sharedData.timeToBurn / 60)min"
            print("🌞 [WidgetViewModel] 📊 Loaded Shared Data:")
            print("   📊 UV Index: \(uvEmoji) \(sharedData.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(sharedData.locationName)")
            print("   ──────────────────────────────────────")
        } else {
            print("🌞 [WidgetViewModel] ❌ No shared data available")
        }
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
        // Color stops for UV 0 to 12+ - matching the main app exactly
        let stops: [(uv: Int, color: Color)] = [
            (0, Color(red: 0.0, green: 0.2, blue: 0.7)),        // #002366
            (1, Color(red: 0.0, green: 0.34, blue: 0.72)),      // #0057B7
            (2, Color(red: 0.0, green: 0.72, blue: 0.72)),      // #00B7B7
            (3, Color(red: 0.0, green: 0.72, blue: 0.0)),       // #00B700
            (4, Color(red: 0.65, green: 0.84, blue: 0.0)),      // #A7D700
            (5, Color(red: 1.0, green: 0.84, blue: 0.0)),       // #FFD700
            (6, Color(red: 1.0, green: 0.72, blue: 0.0)),       // #FFB700
            (7, Color(red: 1.0, green: 0.5, blue: 0.0)),        // #FF7F00
            (8, Color(red: 1.0, green: 0.27, blue: 0.0)),       // #FF4500
            (9, Color(red: 1.0, green: 0.0, blue: 0.0)),        // #FF0000
            (10, Color(red: 0.78, green: 0.0, blue: 0.63)),     // #C800A1
            (11, Color(red: 0.5, green: 0.0, blue: 0.5)),       // #800080
            (12, Color.black)                                   // #000000
        ]
        if uvIndex <= 0 { return stops[0].color }
        if uvIndex >= 12 { return stops.last!.color }
        // For integer UV, just return lower
        let lower = stops[uvIndex]
        return lower.color
    }
    
    func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Check if 24-hour clock is enabled in UserDefaults
        let is24HourClock = UserDefaults.standard.bool(forKey: "is24HourClock")
        formatter.dateFormat = is24HourClock ? "HH:mm" : "h:mm a"
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
    
    // MARK: - Helper Methods for Beautiful Logging
    
    private func getUVEmoji(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0: return "🌙"
        case 1...2: return "🌤️"
        case 3...5: return "☀️"
        case 6...7: return "🔥"
        case 8...10: return "☠️"
        default: return "💀"
        }
    }
} 