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
    
    init(uvIndex: Int, date: Date, timeToBurn: Int? = nil, location: String? = nil, timestamp: Date? = nil, advice: String? = nil) {
        self.uvIndex = uvIndex
        self.date = date
        self.timeToBurn = timeToBurn ?? UVData.calculateTimeToBurn(uvIndex: uvIndex)
        self.location = location
        self.timestamp = timestamp ?? date
        self.advice = advice ?? UVData.getAdvice(uvIndex: uvIndex)
    }
    
    static func calculateTimeToBurn(uvIndex: Int) -> Int {
        // Basic calculation - can be refined based on research
        switch uvIndex {
        case 0...2: return 60 // 1 hour
        case 3...5: return 45 // 45 minutes
        case 6...7: return 30 // 30 minutes
        case 8...10: return 15 // 15 minutes
        case 11: return 10 // 10 minutes
        case 12: return 4 // <5 minutes
        default: return 4 // 4 minutes for any value above 12
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
        case 12:
            return "UV Index 12: Lethal risk. Avoid sun exposure completely. Less than 5 minutes to burn."
        default:
            return "UV Index off the scale! Avoid sun exposure at all costs."
        }
    }
} 