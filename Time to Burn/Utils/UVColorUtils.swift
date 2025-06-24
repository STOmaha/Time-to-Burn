import SwiftUI

struct UVColorUtils {
    
    // MARK: - UV Color Functions
    static func getUVColor(_ uvIndex: Int) -> Color {
        switch uvIndex {
        case 0: return Color(red: 0.0, green: 0.2, blue: 0.7) // Deep blue for UV 0
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    static func getUVCategory(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    // MARK: - Time Formatting Functions
    static func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    static func formatKeyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date).lowercased()
    }
    
    // MARK: - UV Advice Functions
    static func getUVAdvice(uvIndex: Int) -> String {
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
    
    static func calculateTimeToBurn(uvIndex: Int) -> Int {
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
} 