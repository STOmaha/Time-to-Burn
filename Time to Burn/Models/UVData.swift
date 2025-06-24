import Foundation
import WeatherKit

struct UVData: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let uvIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case uvIndex = "value"
    }

    init(from hourWeather: HourWeather) {
        self.date = hourWeather.date
        self.uvIndex = Int(hourWeather.uvIndex.value)
    }

    init(from currentWeather: CurrentWeather) {
        self.date = currentWeather.date
        self.uvIndex = Int(currentWeather.uvIndex.value)
    }
    
    // Add a more flexible initializer
    init(uvIndex: Int, date: Date) {
        self.date = date
        self.uvIndex = uvIndex
    }
    
    static func calculateTimeToBurn(uvIndex: Int) -> Int {
        return UVColorUtils.calculateTimeToBurn(uvIndex: uvIndex)
    }
    
    static func getAdvice(uvIndex: Int) -> String {
        return UVColorUtils.getUVAdvice(uvIndex: uvIndex)
    }
} 