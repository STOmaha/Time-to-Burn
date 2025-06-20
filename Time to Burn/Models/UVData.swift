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
        // More realistic calculation based on common skin type estimates
        switch uvIndex {
        case 0: return .max // Represents infinite time to burn
        case 1...2: return 60
        case 3...5: return 45
        case 6...7: return 30
        case 8...10: return 15
        case 11: return 10
        default: return 5 // For UV index 12 and above
        }
    }
    
    static func getAdvice(uvIndex: Int) -> String {
        switch uvIndex {
        case 0:
            return "No chance of sunburn, safe for all skin types and Vampires. 🧛🏻❤️🧛🏻‍♀️"
        case 1...2:
            return "Low risk of harm from unprotected sun exposure. No protection required."
        case 3...5:
            return "Moderate risk of harm. Wear sunscreen, protective clothing, and seek shade during midday hours."
        case 6...7:
            return "High risk of harm. Reduce time in the sun between 10 a.m. and 4 p.m. Wear protective clothing and sunscreen."
        case 8...10:
            return "Very high risk of harm. Minimize sun exposure during midday hours. Protection against sun damage is essential."
        case 11:
            return "Extreme risk of harm. Take all precautions. Avoid sun exposure during midday hours."
        default:
            return "UV Index is very high! Avoid sun exposure at all costs. Less than 5 minutes to burn."
        }
    }
} 