import Foundation
import WeatherKit

struct UVData: Identifiable {
    let id = UUID()
    let uvIndex: Int
    let timeToBurn: Int // in minutes
    let location: String
    let timestamp: Date
    let advice: String
    
    static func calculateTimeToBurn(uvIndex: Int) -> Int {
        // Basic calculation - can be refined based on research
        switch uvIndex {
        case 0...2: return 60 // 1 hour
        case 3...5: return 45 // 45 minutes
        case 6...7: return 30 // 30 minutes
        case 8...10: return 15 // 15 minutes
        default: return 10 // 10 minutes
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
        default:
            return "Extreme risk of harm. Take all precautions. Avoid sun exposure during midday hours."
        }
    }
} 