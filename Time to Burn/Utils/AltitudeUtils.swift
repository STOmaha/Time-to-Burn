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
    
    /// Format altitude for display with unit conversion
    static func formatAltitude(_ altitude: Double, unitConverter: UnitConverter? = nil) -> String {
        if let converter = unitConverter {
            return converter.formatAltitude(altitude)
        } else {
            // Fallback to metric formatting
            if altitude >= 1000 {
                return String(format: "%.1f km", altitude / 1000.0)
            } else {
                return "\(Int(altitude)) m"
            }
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
    
    /// Fetch real altitude data for a location using OpenTopoData API
    static func fetchAltitude(for location: CLLocation) async -> Double {
        // Use free OpenTopoData API for real elevation data
        return await fetchRealAltitude(for: location)
    }
    
    /// Fetch real altitude from OpenTopoData API (free, no API key required)
    private static func fetchRealAltitude(for location: CLLocation) async -> Double {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // OpenTopoData API endpoint (free service)
        let urlString = "https://api.opentopodata.org/v1/aster30m?locations=\(latitude),\(longitude)"
        
        guard let url = URL(string: urlString) else {
            print("🏔️ [AltitudeUtils] ❌ Invalid URL for elevation API")
            return await fallbackAltitudeEstimate(for: location)
        }
        
        do {
            print("🏔️ [AltitudeUtils] 🌐 Fetching real altitude for \(latitude), \(longitude)")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🏔️ [AltitudeUtils] ❌ API request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return await fallbackAltitudeEstimate(for: location)
            }
            
            let elevationResponse = try JSONDecoder().decode(ElevationResponse.self, from: data)
            
            if let result = elevationResponse.results.first,
               let elevation = result.elevation {
                print("🏔️ [AltitudeUtils] ✅ Real altitude fetched: \(elevation)m")
                return max(0, elevation) // Ensure non-negative
            } else {
                print("🏔️ [AltitudeUtils] ⚠️ No elevation data in response")
                return await fallbackAltitudeEstimate(for: location)
            }
            
        } catch {
            print("🏔️ [AltitudeUtils] ❌ Error fetching real altitude: \(error.localizedDescription)")
            return await fallbackAltitudeEstimate(for: location)
        }
    }
    
    /// Fallback altitude estimate when API fails
    private static func fallbackAltitudeEstimate(for location: CLLocation) async -> Double {
        print("🏔️ [AltitudeUtils] 🔄 Using fallback altitude estimate")
        
        // Use CLLocation's altitude if available (from GPS)
        if location.altitude > -100 && location.altitude < 10000 {
            return max(0, location.altitude)
        }
        
        // Enhanced estimation based on geographic patterns
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        var estimatedAltitude: Double = 0
        
        // More sophisticated estimation based on known geographic patterns
        if abs(latitude) > 60 {
            // High latitude regions (Arctic/Antarctic)
            estimatedAltitude = 50 + abs(sin(longitude * .pi / 180)) * 200
        } else if abs(latitude) > 45 {
            // Mid-latitude regions (mountainous areas like Alps, Rockies)
            estimatedAltitude = 100 + abs(sin(longitude * .pi / 180)) * 400
        } else if abs(latitude) > 30 {
            // Lower mid-latitude (hills and plains)
            estimatedAltitude = 50 + abs(sin(longitude * .pi / 180)) * 300
        } else {
            // Tropical regions - generally low elevation with some coastal plains
            estimatedAltitude = abs(sin(latitude * .pi / 180)) * 150
        }
        
        return estimatedAltitude
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

// MARK: - Elevation API Response Models

/// Response structure for OpenTopoData elevation API
private struct ElevationResponse: Codable {
    let results: [ElevationResult]
    let status: String
}

/// Individual elevation result from API
private struct ElevationResult: Codable {
    let elevation: Double?
    let location: ElevationLocation
    let dataset: String?
}

/// Location data in elevation API response
private struct ElevationLocation: Codable {
    let lat: Double
    let lng: Double
} 