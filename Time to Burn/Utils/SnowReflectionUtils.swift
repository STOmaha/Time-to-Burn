import Foundation
import WeatherKit

struct SnowReflectionUtils {
    
    // MARK: - Snow Reflection Calculations
    
    /// Calculate UV reflection factor from snow
    /// Fresh snow can reflect up to 80% of UV radiation
    static func calculateSnowReflectionFactor(snowType: SnowConditions.SnowType, coverage: Double) -> Double {
        let baseReflection = snowType.reflectionFactor
        let coverageFactor = coverage / 100.0
        
        return baseReflection * coverageFactor
    }
    
    /// Calculate additional UV exposure from snow reflection
    static func calculateAdditionalUVFromSnow(snowConditions: SnowConditions, baseUV: Int) -> Int {
        let reflectionFactor = calculateSnowReflectionFactor(
            snowType: snowConditions.snowType,
            coverage: snowConditions.snowCoverage
        )
        
        let additionalUV = Double(baseUV) * reflectionFactor
        return Int(round(additionalUV))
    }
    
    /// Get total UV exposure including snow reflection
    static func getTotalUVWithSnowReflection(baseUV: Int, snowConditions: SnowConditions) -> Int {
        let additionalUV = calculateAdditionalUVFromSnow(snowConditions: snowConditions, baseUV: baseUV)
        return baseUV + additionalUV
    }
    
    // MARK: - Snow Condition Analysis
    
    /// Determine snow type based on weather conditions and age
    static func determineSnowType(snowDepth: Double, snowAge: Int, temperature: Double) -> SnowConditions.SnowType {
        guard snowDepth > 0 else { return .none }
        
        if snowAge <= 1 {
            return .fresh
        } else if snowAge <= 3 {
            return temperature > 0 ? .melting : .packed
        } else if snowAge <= 7 {
            return temperature > 0 ? .melting : .packed
        } else {
            return temperature > 0 ? .melting : .icy
        }
    }
    
    /// Calculate snow age in days
    static func calculateSnowAge(lastSnowfall: Date?) -> Int {
        guard let lastSnowfall = lastSnowfall else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: lastSnowfall, to: now)
        
        return components.day ?? 0
    }
    
    /// Get snow risk level
    static func getSnowRiskLevel(snowConditions: SnowConditions) -> SnowRiskLevel {
        guard snowConditions.snowCoverage > 0 else { return .none }
        
        let reflectionFactor = calculateSnowReflectionFactor(
            snowType: snowConditions.snowType,
            coverage: snowConditions.snowCoverage
        )
        
        switch reflectionFactor {
        case 0.0..<0.2:
            return .low
        case 0.2..<0.4:
            return .moderate
        case 0.4..<0.6:
            return .high
        case 0.6...:
            return .extreme
        default:
            return .low
        }
    }
    
    // MARK: - Snow Risk Levels
    
    enum SnowRiskLevel: String, CaseIterable {
        case none = "None"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case extreme = "Extreme"
        
        var color: String {
            switch self {
            case .none: return "clear"
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .extreme: return "red"
            }
        }
        
        var description: String {
            switch self {
            case .none: return "No snow present"
            case .low: return "Minimal snow reflection"
            case .moderate: return "Moderate snow reflection"
            case .high: return "High snow reflection - take extra precautions"
            case .extreme: return "Extreme snow reflection - maximum protection needed"
            }
        }
        
        var uvIncrease: String {
            switch self {
            case .none: return "0%"
            case .low: return "0-20%"
            case .moderate: return "20-40%"
            case .high: return "40-60%"
            case .extreme: return "60%+"
            }
        }
    }
    
    // MARK: - Snow Data Fetching
    
    /// Fetch snow conditions from weather data
    static func fetchSnowConditions(from weather: CurrentWeather) async -> SnowConditions {
        // Note: WeatherKit doesn't provide detailed snow data
        // In a real app, you'd use additional weather services or APIs
        
        let snowDepth = await estimateSnowDepth(from: weather)
        let snowCoverage = await estimateSnowCoverage(from: weather)
        let snowAge = await estimateSnowAge(from: weather)
        let snowType = determineSnowType(
            snowDepth: snowDepth,
            snowAge: snowAge,
            temperature: weather.temperature.value
        )
        
        return SnowConditions(
            hasRecentSnowfall: snowAge <= 3,
            snowDepth: snowDepth,
            snowCoverage: snowCoverage,
            snowAge: snowAge,
            snowType: snowType
        )
    }
    
    /// Estimate snow depth from weather conditions (placeholder)
    private static func estimateSnowDepth(from weather: CurrentWeather) async -> Double {
        // This is a simplified estimation
        // In a production app, you'd use specialized snow data APIs
        
        let temperature = weather.temperature.value
        let condition = weather.condition
        
        // Very basic estimation based on temperature and conditions
        switch condition {
        case .snow, .sleet, .wintryMix:
            return Double.random(in: 5...50)
        case .freezingDrizzle, .freezingRain:
            return Double.random(in: 1...10)
        default:
            return 0
        }
    }
    
    /// Estimate snow coverage from weather conditions (placeholder)
    private static func estimateSnowCoverage(from weather: CurrentWeather) async -> Double {
        // This is a simplified estimation
        let condition = weather.condition
        
        switch condition {
        case .snow, .sleet, .wintryMix:
            return Double.random(in: 50...100)
        case .freezingDrizzle, .freezingRain:
            return Double.random(in: 10...30)
        default:
            return 0
        }
    }
    
    /// Estimate snow age from weather conditions (placeholder)
    private static func estimateSnowAge(from weather: CurrentWeather) async -> Int {
        // This is a simplified estimation
        // In a real app, you'd track actual snowfall events
        
        let condition = weather.condition
        
        switch condition {
        case .snow, .sleet, .wintryMix:
            return Int.random(in: 0...2) // Recent snow
        case .freezingDrizzle, .freezingRain:
            return Int.random(in: 1...5) // Older snow
        default:
            return Int.random(in: 5...30) // Old snow or no snow
        }
    }
    
    // MARK: - Snow-Based Recommendations
    
    static func getSnowRecommendations(snowConditions: SnowConditions) -> [String] {
        let riskLevel = getSnowRiskLevel(snowConditions: snowConditions)
        
        var recommendations: [String] = []
        
        switch riskLevel {
        case .none:
            recommendations.append("No snow present - normal UV protection")
            
        case .low:
            recommendations.append("Light snow reflection - standard protection")
            recommendations.append("Apply sunscreen to exposed areas")
            
        case .moderate:
            recommendations.append("Moderate snow reflection detected")
            recommendations.append("Use SPF 30+ sunscreen")
            recommendations.append("Wear UV-protective sunglasses")
            recommendations.append("Apply sunscreen to face and neck")
            
        case .high:
            recommendations.append("High snow reflection - take extra precautions")
            recommendations.append("Use SPF 50+ sunscreen")
            recommendations.append("Wear UV-protective eyewear")
            recommendations.append("Apply sunscreen every 1-2 hours")
            recommendations.append("Cover exposed skin with clothing")
            recommendations.append("Use lip balm with SPF")
            
        case .extreme:
            recommendations.append("Extreme snow reflection - maximum protection needed")
            recommendations.append("Use maximum SPF protection")
            recommendations.append("Apply sunscreen every hour")
            recommendations.append("Wear wide-brimmed hat")
            recommendations.append("Cover all exposed skin")
            recommendations.append("Seek shade frequently")
            recommendations.append("Monitor for sunburn symptoms")
        }
        
        return recommendations
    }
    
    // MARK: - Snow Education Content
    
    static func getSnowEducationContent(snowConditions: SnowConditions) -> String {
        let riskLevel = getSnowRiskLevel(snowConditions: snowConditions)
        
        switch riskLevel {
        case .none:
            return "No snow present. UV exposure is normal for current conditions."
            
        case .low:
            return "Light snow cover may reflect some UV rays. Standard sun protection is usually sufficient."
            
        case .moderate:
            return "Snow reflects UV radiation, increasing your exposure. Fresh snow can reflect up to 80% of UV rays, effectively doubling your UV exposure."
            
        case .high:
            return "Significant snow cover creates high UV reflection. The combination of direct UV and reflected UV from snow can cause rapid sunburn and eye damage."
            
        case .extreme:
            return "Extreme snow conditions create the highest UV exposure possible. Snow reflects up to 80% of UV radiation, and combined with high altitude effects, can cause severe sunburn in minutes."
        }
    }
    
    // MARK: - Snow UI Helpers
    
    static func getSnowEmoji(snowConditions: SnowConditions) -> String {
        guard snowConditions.snowCoverage > 0 else { return "☀️" }
        
        switch snowConditions.snowType {
        case .none:
            return "☀️"
        case .fresh:
            return "❄️"
        case .packed:
            return "🏂"
        case .melting:
            return "🌨️"
        case .icy:
            return "🧊"
        }
    }
    
    static func getSnowDescription(snowConditions: SnowConditions) -> String {
        guard snowConditions.snowCoverage > 0 else { return "No snow" }
        
        return "\(snowConditions.snowType.rawValue) snow (\(Int(snowConditions.snowCoverage))% coverage)"
    }
    
    static func formatSnowDepth(_ depth: Double) -> String {
        if depth >= 100 {
            return String(format: "%.1f m", depth / 100.0)
        } else {
            return "\(Int(depth)) cm"
        }
    }
} 