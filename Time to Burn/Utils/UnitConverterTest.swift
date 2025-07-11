import Foundation

// MARK: - Unit Converter Test
struct UnitConverterTest {
    
    static func runTests() {
        print("🧪 [UnitConverterTest] Starting tests...")
        
        // Test temperature conversions
        testTemperatureConversions()
        
        // Test distance conversions
        testDistanceConversions()
        
        // Test time formatting
        testTimeFormatting()
        
        // Test unit symbols
        testUnitSymbols()
        
        print("✅ [UnitConverterTest] All tests completed!")
    }
    
    private static func testTemperatureConversions() {
        print("\n🌡️ Testing Temperature Conversions:")
        
        let testTemps = [0.0, 25.0, 100.0, -10.0]
        
        for temp in testTemps {
            let fahrenheit = UnitConverter.celsiusToFahrenheit(temp)
            let backToCelsius = UnitConverter.fahrenheitToCelsius(fahrenheit)
            print("   \(temp)°C = \(fahrenheit)°F, \(fahrenheit)°F = \(backToCelsius)°C")
        }
    }
    
    private static func testDistanceConversions() {
        print("\n📏 Testing Distance Conversions:")
        
        let testDistances = [0.0, 1.0, 10.0, 42.195]
        
        for km in testDistances {
            let miles = UnitConverter.kilometersToMiles(km)
            let backToKm = UnitConverter.milesToKilometers(miles)
            print("   \(km) km = \(miles) mi, \(miles) mi = \(backToKm) km")
        }
    }
    
    private static func testTimeFormatting() {
        print("\n⏱️ Testing Time Formatting:")
        
        let time: TimeInterval = 3665 // 1h 1m 5s
        let standard = UnitConverter.shared.formatTime(time, style: .standard)
        let short = UnitConverter.shared.formatTime(time, style: .short)
        let compact = UnitConverter.shared.formatTime(time, style: .compact)
        print("   Standard: \(standard)")
        print("   Short: \(short)")
        print("   Compact: \(compact)")
    }
    
    private static func testUnitSymbols() {
        print("\n🔣 Testing Unit Symbols:")
        
        // Set metric
        SettingsManager.shared.isMetricUnits = true
        print("   Metric temp symbol: \(UnitConverter.shared.temperatureSymbol())")
        print("   Metric distance symbol: \(UnitConverter.shared.distanceSymbol())")
        print("   Metric speed symbol: \(UnitConverter.shared.speedSymbol())")
        print("   Metric temp: \(UnitConverter.shared.formatTemperature(25.0))")
        print("   Metric distance: \(UnitConverter.shared.formatDistance(10.0))")
        print("   Metric speed: \(UnitConverter.shared.formatSpeed(100.0))")
        
        // Set imperial
        SettingsManager.shared.isMetricUnits = false
        print("   Imperial temp symbol: \(UnitConverter.shared.temperatureSymbol())")
        print("   Imperial distance symbol: \(UnitConverter.shared.distanceSymbol())")
        print("   Imperial speed symbol: \(UnitConverter.shared.speedSymbol())")
        print("   Imperial temp: \(UnitConverter.shared.formatTemperature(25.0))")
        print("   Imperial distance: \(UnitConverter.shared.formatDistance(10.0))")
        print("   Imperial speed: \(UnitConverter.shared.formatSpeed(100.0))")
    }
}

// MARK: - Integration Tests
extension UnitConverterTest {
    
    static func testSettingsManagerIntegration() {
        print("\n🔗 Testing SettingsManager Integration:")
        
        // Set metric
        SettingsManager.shared.isMetricUnits = true
        let testTemp = 25.0
        let testDistance = 10.0
        let metricTemp = UnitConverter.shared.formatTemperature(testTemp)
        let metricDistance = UnitConverter.shared.formatDistance(testDistance)
        print("   Metric: \(testTemp)°C = \(metricTemp), \(testDistance) km = \(metricDistance)")
        
        // Set imperial
        SettingsManager.shared.isMetricUnits = false
        let imperialTemp = UnitConverter.shared.formatTemperature(testTemp)
        let imperialDistance = UnitConverter.shared.formatDistance(testDistance)
        print("   Imperial: \(testTemp)°C = \(imperialTemp), \(testDistance) km = \(imperialDistance)")
    }
} 