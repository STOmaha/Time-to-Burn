import Foundation
import CoreLocation

struct AltitudeUtils {
    
    // MARK: - Altitude Calculations
    
    /// Calculate UV multiplier based on altitude
    /// UV increases by approximately 10% per 1000m elevation
    static func calculateUVMultiplier(altitude: Double) -> Double {
        let altitudeInKm = altitude / 1000.0
        return 1.0 + (altitudeInKm * 0.1)
    }
    
    /// Calculate altitude risk level
    static func getAltitudeRiskLevel(altitude: Double) -> AltitudeRiskLevel {
        switch altitude {
        case 0..<1000:
            return .low
        case 1000..<2000:
            return .moderate
        case 2000..<3000:
            return .high
        case 3000..<4000:
            return .veryHigh
        case 4000...:
            return .extreme
        default:
            return .low
        }
    }
    
    /// Get altitude description for UI
    static func getAltitudeDescription(altitude: Double) -> String {
        let riskLevel = getAltitudeRiskLevel(altitude: altitude)
        return "\(Int(altitude))m above sea level - \(riskLevel.description)"
    }
    
    /// Format altitude for display
    static func formatAltitude(_ altitude: Double) -> String {
        if altitude >= 1000 {
            return String(format: "%.1f km", altitude / 1000.0)
        } else {
            return "\(Int(altitude)) m"
        }
    }
    
    /// Get altitude emoji for UI
    static func getAltitudeEmoji(altitude: Double) -> String {
        switch altitude {
        case 0..<500:
            return "🏞️"
        case 500..<1000:
            return "⛰️"
        case 1000..<2000:
            return "🏔️"
        case 2000..<3000:
            return "🗻"
        case 3000..<4000:
            return "🏔️"
        case 4000...:
            return "❄️"
        default:
            return "🏞️"
        }
    }
    
    // MARK: - Altitude Risk Levels
    
    enum AltitudeRiskLevel: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        case extreme = "Extreme"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .veryHigh: return "red"
            case .extreme: return "purple"
            }
        }
        
        var description: String {
            switch self {
            case .low: return "Minimal altitude effect on UV"
            case .moderate: return "Moderate increase in UV exposure"
            case .high: return "Significant increase in UV exposure"
            case .veryHigh: return "Very high UV exposure at altitude"
            case .extreme: return "Extreme UV exposure - take maximum precautions"
            }
        }
        
        var uvIncrease: String {
            switch self {
            case .low: return "0-10%"
            case .moderate: return "10-20%"
            case .high: return "20-30%"
            case .veryHigh: return "30-40%"
            case .extreme: return "40%+"
            }
        }
    }
    
    // MARK: - Altitude Data Fetching
    
    /// Fetch altitude data for a location using Core Location
    static func fetchAltitude(for location: CLLocation) async -> Double {
        // Note: Core Location doesn't provide altitude directly
        // In a real app, you'd use a third-party service like:
        // - Google Elevation API
        // - OpenTopoData API
        // - USGS Elevation Point Query Service
        
        // For now, we'll use a placeholder that could be enhanced
        return await estimateAltitudeFromLocation(location)
    }
    
    /// Estimate altitude based on location (placeholder implementation)
    private static func estimateAltitudeFromLocation(_ location: CLLocation) async -> Double {
        // This is a simplified estimation
        // In a production app, you'd use a proper elevation API
        
        let latitude = location.coordinate.latitude
        let _ = location.coordinate.longitude
        
        // Simple estimation based on latitude (mountains tend to be at certain latitudes)
        // This is just for demonstration - not accurate
        var estimatedAltitude: Double = 0
        
        // Rough estimation based on latitude bands
        if abs(latitude) > 60 {
            // High latitude - likely some elevation
            estimatedAltitude = Double.random(in: 100...500)
        } else if abs(latitude) > 45 {
            // Mid latitude - moderate elevation possible
            estimatedAltitude = Double.random(in: 50...300)
        } else if abs(latitude) > 30 {
            // Lower latitude - lower elevation likely
            estimatedAltitude = Double.random(in: 0...200)
        } else {
            // Tropical - generally low elevation
            estimatedAltitude = Double.random(in: 0...100)
        }
        
        // Add some randomness to simulate real data
        estimatedAltitude += Double.random(in: -50...50)
        
        return max(0, estimatedAltitude)
    }
    
    // MARK: - Altitude-Based Recommendations
    
    static func getAltitudeRecommendations(altitude: Double) -> [String] {
        let riskLevel = getAltitudeRiskLevel(altitude: altitude)
        
        var recommendations: [String] = []
        
        switch riskLevel {
        case .low:
            recommendations.append("Normal UV protection sufficient")
            
        case .moderate:
            recommendations.append("Use SPF 30+ sunscreen")
            recommendations.append("Reapply sunscreen more frequently")
            
        case .high:
            recommendations.append("Use SPF 50+ sunscreen")
            recommendations.append("Apply sunscreen every 1-2 hours")
            recommendations.append("Wear UV-protective eyewear")
            recommendations.append("Stay hydrated")
            
        case .veryHigh:
            recommendations.append("Use maximum SPF protection")
            recommendations.append("Apply sunscreen every hour")
            recommendations.append("Wear wide-brimmed hat")
            recommendations.append("Seek shade frequently")
            recommendations.append("Monitor for sunburn symptoms")
            
        case .extreme:
            recommendations.append("Avoid prolonged sun exposure")
            recommendations.append("Use maximum protection measures")
            recommendations.append("Stay in shade when possible")
            recommendations.append("Monitor skin for early sunburn signs")
            recommendations.append("Consider postponing outdoor activities")
        }
        
        return recommendations
    }
    
    // MARK: - Altitude Education Content
    
    static func getAltitudeEducationContent(altitude: Double) -> String {
        let riskLevel = getAltitudeRiskLevel(altitude: altitude)
        
        switch riskLevel {
        case .low:
            return "At this altitude, UV exposure is similar to sea level. Standard sun protection measures are appropriate."
            
        case .moderate:
            return "UV intensity increases with altitude. The atmosphere is thinner, providing less natural UV protection. Take extra precautions."
            
        case .high:
            return "High altitude significantly increases UV exposure. The thinner atmosphere filters less UV radiation, and snow/ice can reflect additional UV rays."
            
        case .veryHigh:
            return "Very high altitude creates extreme UV conditions. The combination of thin atmosphere and potential snow reflection requires maximum protection."
            
        case .extreme:
            return "Extreme altitude conditions create the highest UV exposure possible. The atmosphere provides minimal UV filtering, and snow/ice reflection can double UV exposure."
        }
    }
} 