import Foundation
import SwiftUI

// MARK: - Centralized Unit Conversion System
class UnitConverter: ObservableObject {
    static let shared = UnitConverter()
    
    // MARK: - Settings Manager Integration
    @Published var settingsManager: SettingsManager?
    
    private init() {
        print("🌍 [UnitConverter] 🚀 Initializing centralized unit conversion system")
    }
    
    // MARK: - Setup
    func configure(with settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        print("🌍 [UnitConverter] ✅ Configured with SettingsManager")
    }
    
    // MARK: - Core Conversion Methods
    
    // Temperature Conversions
    static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }
    
    static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32) * 5/9
    }
    
    // Distance Conversions
    static func kilometersToMiles(_ kilometers: Double) -> Double {
        return kilometers * 0.621371
    }
    
    static func milesToKilometers(_ miles: Double) -> Double {
        return miles * 1.60934
    }
    
    // Altitude Conversions
    static func metersToFeet(_ meters: Double) -> Double {
        return meters * 3.28084
    }
    
    static func feetToMeters(_ feet: Double) -> Double {
        return feet * 0.3048
    }
    
    // MARK: - Smart Conversion Methods (Auto-detect units)
    
    func convertTemperature(_ temperature: Double, from metric: Bool) -> Double {
        if metric {
            // Input is Celsius, return as is
            return temperature
        } else {
            // Input is Celsius, convert to Fahrenheit
            return UnitConverter.celsiusToFahrenheit(temperature)
        }
    }
    
    func convertDistance(_ distance: Double, from metric: Bool) -> Double {
        if metric {
            // Input is kilometers, return as is
            return distance
        } else {
            // Input is kilometers, convert to miles
            return UnitConverter.kilometersToMiles(distance)
        }
    }
    
    func convertAltitude(_ altitude: Double, from metric: Bool) -> Double {
        if metric {
            // Input is meters, return as is
            return altitude
        } else {
            // Input is meters, convert to feet
            return UnitConverter.metersToFeet(altitude)
        }
    }
    
    // MARK: - Unit Symbols
    
    func temperatureSymbol() -> String {
        guard let settingsManager = settingsManager else { return "°C" }
        return settingsManager.isMetricUnits ? "°C" : "°F"
    }
    
    func distanceSymbol() -> String {
        guard let settingsManager = settingsManager else { return "km" }
        return settingsManager.isMetricUnits ? "km" : "mi"
    }
    
    func speedSymbol() -> String {
        guard let settingsManager = settingsManager else { return "km/h" }
        return settingsManager.isMetricUnits ? "km/h" : "mph"
    }
    
    func altitudeSymbol() -> String {
        guard let settingsManager = settingsManager else { return "m" }
        return settingsManager.isMetricUnits ? "m" : "ft"
    }
    
    // MARK: - Formatted Display Methods
    
    func formatTemperature(_ temperature: Double) -> String {
        guard let settingsManager = settingsManager else {
            return String(format: "%.1f°C", temperature)
        }
        
        let convertedTemp = convertTemperature(temperature, from: settingsManager.isMetricUnits)
        let symbol = temperatureSymbol()
        return String(format: "%.1f%@", convertedTemp, symbol)
    }
    
    func formatDistance(_ distance: Double) -> String {
        guard let settingsManager = settingsManager else {
            return String(format: "%.1f km", distance)
        }
        
        let convertedDistance = convertDistance(distance, from: settingsManager.isMetricUnits)
        let symbol = distanceSymbol()
        return String(format: "%.1f %@", convertedDistance, symbol)
    }
    
    func formatSpeed(_ speed: Double) -> String {
        guard let settingsManager = settingsManager else {
            return String(format: "%.1f km/h", speed)
        }
        
        let convertedSpeed = convertDistance(speed, from: settingsManager.isMetricUnits)
        let symbol = speedSymbol()
        return String(format: "%.1f %@", convertedSpeed, symbol)
    }
    
    func formatAltitude(_ altitude: Double) -> String {
        guard let settingsManager = settingsManager else {
            if altitude >= 1000 {
                return String(format: "%.1f km", altitude / 1000.0)
            } else {
                return "\(Int(altitude)) m"
            }
        }
        
        let convertedAltitude = convertAltitude(altitude, from: settingsManager.isMetricUnits)
        
        if settingsManager.isMetricUnits {
            // Metric: use meters or kilometers
            if convertedAltitude >= 1000 {
                return String(format: "%.1f km", convertedAltitude / 1000.0)
            } else {
                return "\(Int(convertedAltitude)) m"
            }
        } else {
            // Imperial: use feet
            if convertedAltitude >= 5280 {
                return String(format: "%.1f mi", convertedAltitude / 5280.0)
            } else {
                return "\(Int(convertedAltitude)) ft"
            }
        }
    }
    
    func formatDistanceWithUnits(_ distance: Double) -> String {
        guard let settingsManager = settingsManager else {
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000.0)
            } else {
                return "\(Int(distance)) m"
            }
        }
        
        if settingsManager.isMetricUnits {
            // Metric: meters or kilometers
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000.0)
            } else {
                return "\(Int(distance)) m"
            }
        } else {
            // Imperial: feet or miles
            let distanceInFeet = UnitConverter.metersToFeet(distance)
            if distanceInFeet >= 5280 {
                return String(format: "%.1f mi", distanceInFeet / 5280.0)
            } else {
                return "\(Int(distanceInFeet)) ft"
            }
        }
    }
    
    // MARK: - Time Formatting (No unit conversion needed)
    
    func formatTime(_ timeInterval: TimeInterval, style: TimeFormatStyle = .standard) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        switch style {
        case .standard:
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        case .short:
            if hours > 0 {
                return String(format: "%dh %dm", hours, minutes)
            } else {
                return String(format: "%dm %ds", minutes, seconds)
            }
        case .compact:
            if hours > 0 {
                return String(format: "%dh", hours)
            } else if minutes > 0 {
                return String(format: "%dm", minutes)
            } else {
                return String(format: "%ds", seconds)
            }
        }
    }
    
    // MARK: - Date/Time Formatting with 24-hour support
    
    func formatHour(_ date: Date) -> String {
        guard let settingsManager = settingsManager else {
            return formatHourDefault(date)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = settingsManager.is24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
    
    func formatTimeOfDay(_ date: Date) -> String {
        guard let settingsManager = settingsManager else {
            return formatTimeOfDayDefault(date)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = settingsManager.is24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
    
    // Default formatting methods (fallback)
    private func formatHourDefault(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatTimeOfDayDefault(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // MARK: - UV-Specific Formatting (No unit conversion needed)
    
    func formatUVIndex(_ uvIndex: Int) -> String {
        return "UV \(uvIndex)"
    }
    
    func formatTimeToBurn(_ uvIndex: Int) -> String {
        if uvIndex == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurnMinutes(uvIndex: uvIndex)
        return "\(minutes) minutes"
    }
    
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.0f%%", value * 100)
    }
    
    // MARK: - Weather Data Formatting
    
    func formatWeatherData(_ temperature: Double) -> String {
        return formatTemperature(temperature)
    }
    
    func formatWindSpeed(_ speed: Double) -> String {
        return formatSpeed(speed)
    }
    
    func formatVisibility(_ visibility: Double) -> String {
        return formatDistance(visibility)
    }
}

// MARK: - Time Format Styles
enum TimeFormatStyle {
    case standard  // 1:23:45 or 23:45
    case short     // 1h 23m or 23m 45s
    case compact   // 1h or 23m or 45s
}

// MARK: - View Extensions for Easy Integration
extension View {
    func withUnitConversion<T>(_ value: T, converter: (T) -> String) -> some View {
        self
    }
}

// MARK: - Debug and Testing
extension UnitConverter {
    
    func testConversions() {
        print("🌍 [UnitConverter] 🧪 Testing conversions...")
        
        // Test temperature conversions
        let testCelsius = 25.0
        let fahrenheit = UnitConverter.celsiusToFahrenheit(testCelsius)
        let backToCelsius = UnitConverter.fahrenheitToCelsius(fahrenheit)
        print("   🌡️ \(testCelsius)°C = \(fahrenheit)°F")
        print("   🌡️ \(fahrenheit)°F = \(backToCelsius)°C")
        
        // Test distance conversions
        let testKm = 10.0
        let miles = UnitConverter.kilometersToMiles(testKm)
        let backToKm = UnitConverter.milesToKilometers(miles)
        print("   📏 \(testKm) km = \(miles) mi")
        print("   📏 \(miles) mi = \(backToKm) km")
        
        // Test time formatting
        let testTime: TimeInterval = 3665 // 1h 1m 5s
        print("   ⏱️ Standard: \(formatTime(testTime, style: .standard))")
        print("   ⏱️ Short: \(formatTime(testTime, style: .short))")
        print("   ⏱️ Compact: \(formatTime(testTime, style: .compact))")
        
        // Test UV formatting
        let testUV = 8
        print("   ☀️ UV Index: \(formatUVIndex(testUV))")
        print("   ⏰ Time to Burn: \(formatTimeToBurn(testUV))")
    }
} 