import Foundation
import WeatherKit

struct UVData: Identifiable {
    let id = UUID()
    let uvIndex: Int
    let date: Date
    let timeToBurn: Int? // in minutes
    let location: String?
    let timestamp: Date?
    let advice: String?
    
    init(from hourWeather: HourWeather) {
        self.uvIndex = Int(hourWeather.uvIndex.value)
        self.date = hourWeather.date
        self.timeToBurn = UVData.calculateTimeToBurn(uvIndex: Int(hourWeather.uvIndex.value))
        self.advice = UVData.getAdvice(uvIndex: Int(hourWeather.uvIndex.value))
        self.location = nil
        self.timestamp = nil
    }

    init(from currentWeather: CurrentWeather) {
        self.uvIndex = Int(currentWeather.uvIndex.value)
        self.date = currentWeather.date
        self.timeToBurn = UVData.calculateTimeToBurn(uvIndex: Int(currentWeather.uvIndex.value))
        self.advice = UVData.getAdvice(uvIndex: Int(currentWeather.uvIndex.value))
        self.location = nil
        self.timestamp = nil
    }
    
    // Add a more flexible initializer
    init(uvIndex: Int, date: Date, timeToBurn: Int? = nil, advice: String? = nil, location: String? = nil, timestamp: Date? = nil) {
        self.uvIndex = uvIndex
        self.date = date
        self.timeToBurn = timeToBurn ?? UVData.calculateTimeToBurn(uvIndex: uvIndex)
        self.advice = advice ?? UVData.getAdvice(uvIndex: uvIndex)
        self.location = location
        self.timestamp = timestamp
    }
    
    static func calculateTimeToBurn(uvIndex: Int) -> Int {
        // Simplified calculation
        if uvIndex <= 0 { return 0 }
        return 60 / uvIndex
    }
    
    static func getAdvice(uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low danger. No protection needed."
        case 3...5: return "Moderate risk. Seek shade during midday hours."
        case 6...7: return "High risk. Wear protective clothing and sunscreen."
        case 8...10: return "Very high risk. Avoid being outside during midday hours."
        default: return "Extreme risk. Stay indoors."
        }
    }
} 