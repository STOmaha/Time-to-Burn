import SwiftUI

struct UVColorUtils {
    
    // MARK: - UV Color Functions
    static func getUVColor(_ uvIndex: Int) -> Color {
        // Color stops for UV 0 to 12+
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
        return UnitConverter.shared.formatHour(date)
    }
    
    static func formatKeyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = UnitConverter.shared.settingsManager?.is24HourClock == true ? "HH" : "h a"
        let timeString = formatter.string(from: date)
        return UnitConverter.shared.settingsManager?.is24HourClock == true ? timeString : timeString.lowercased()
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
        if uvIndex == 0 { return .max } // Infinite
        if uvIndex >= 12 { return 5 * 60 } // 5 minutes in seconds
        // Linear interpolation from 60 minutes (UV 1) to 5 minutes (UV 12) in seconds
        let burnMinutes = 60 - Int(round(Double(uvIndex - 1) * 55.0 / 11.0))
        return burnMinutes * 60 // Convert to seconds
    }
    
    static func calculateTimeToBurnMinutes(uvIndex: Int) -> Int {
        if uvIndex == 0 { return .max } // Infinite
        if uvIndex >= 12 { return 5 } // 5 minutes
        // Linear interpolation from 60 minutes (UV 1) to 5 minutes (UV 12)
        return 60 - Int(round(Double(uvIndex - 1) * 55.0 / 11.0))
    }
    
    static func getPastelUVColor(_ uvIndex: Int) -> Color {
        let base = getUVColor(uvIndex)
        // Linearly interpolate with white for a pastel effect
        let pastel = Color(
            red: 1.0 - (1.0 - base.components().r) * 0.18,
            green: 1.0 - (1.0 - base.components().g) * 0.18,
            blue: 1.0 - (1.0 - base.components().b) * 0.18
        )
        return pastel
    }
    
    // MARK: - Homogeneous Background Color
    static func getHomogeneousBackgroundColor(_ uvIndex: Int) -> Color {
        let base = getUVColor(uvIndex)
        // Create a very subtle background that works across all tabs
        // More subtle than pastel for better readability
        let homogeneous = Color(
            red: 1.0 - (1.0 - base.components().r) * 0.08,
            green: 1.0 - (1.0 - base.components().g) * 0.08,
            blue: 1.0 - (1.0 - base.components().b) * 0.08
        )
        return homogeneous
    }
    
    // MARK: - Tab Bar Background Color
    static func getTabBarBackgroundColor(_ uvIndex: Int) -> Color {
        let base = getUVColor(uvIndex)
        // Slightly more pronounced for tab bar
        let tabBar = Color(
            red: 1.0 - (1.0 - base.components().r) * 0.12,
            green: 1.0 - (1.0 - base.components().g) * 0.12,
            blue: 1.0 - (1.0 - base.components().b) * 0.12
        )
        return tabBar
    }
}

// MARK: - Color Components Extension
import SwiftUI

extension Color {
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return (0, 0, 0, 1)
        #endif
    }
} 