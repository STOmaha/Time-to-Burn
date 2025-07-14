import Foundation
import CoreLocation

struct WaterReflectionUtils {
    
    // MARK: - Water Reflection Calculations
    
    /// Calculate UV reflection factor from water
    /// Water can reflect up to 25% of UV radiation
    static func calculateWaterReflectionFactor(waterType: WaterProximity.WaterBodyType, distance: Double, size: WaterProximity.WaterBodySize) -> Double {
        let baseReflection = waterType.reflectionFactor
        let sizeMultiplier = size.sizeMultiplier
        
        // Distance factor (closer = more reflection)
        let distanceFactor = max(0.1, 1.0 - (distance / 1000.0))
        
        return baseReflection * sizeMultiplier * distanceFactor
    }
    
    /// Calculate additional UV exposure from water reflection
    static func calculateAdditionalUVFromWater(waterProximity: WaterProximity, baseUV: Int) -> Int {
        guard waterProximity.distanceToWater < 1000 else { return 0 }
        
        let reflectionFactor = calculateWaterReflectionFactor(
            waterType: waterProximity.waterBodyType,
            distance: waterProximity.distanceToWater,
            size: waterProximity.nearestWaterBody?.size ?? .medium
        )
        
        let additionalUV = Double(baseUV) * reflectionFactor
        return Int(round(additionalUV))
    }
    
    /// Get total UV exposure including water reflection
    static func getTotalUVWithWaterReflection(baseUV: Int, waterProximity: WaterProximity) -> Int {
        let additionalUV = calculateAdditionalUVFromWater(waterProximity: waterProximity, baseUV: baseUV)
        return baseUV + additionalUV
    }
    
    // MARK: - Water Proximity Analysis
    
    /// Determine if location is coastal
    static func isCoastalLocation(latitude: Double, longitude: Double) -> Bool {
        // This is a simplified check
        // In a real app, you'd use a coastal database or API
        
        // Check if near major coastlines (very rough approximation)
        let isNearOcean = abs(latitude) < 60 && (
            abs(longitude) > 160 || // Pacific
            abs(longitude) < 20 ||  // Atlantic
            (latitude > 30 && latitude < 50 && longitude > 100 && longitude < 140) // Asia
        )
        
        return isNearOcean
    }
    
    /// Calculate distance to nearest water body
    static func calculateDistanceToWater(from location: CLLocation, to waterBody: WaterProximity.WaterBody) -> Double {
        let waterLocation = CLLocation(latitude: waterBody.coordinates.latitude, longitude: waterBody.coordinates.longitude)
        return location.distance(from: waterLocation)
    }
    
    /// Get water risk level
    static func getWaterRiskLevel(waterProximity: WaterProximity) -> WaterRiskLevel {
        guard waterProximity.distanceToWater < 1000 else { return .none }
        
        let reflectionFactor = calculateWaterReflectionFactor(
            waterType: waterProximity.waterBodyType,
            distance: waterProximity.distanceToWater,
            size: waterProximity.nearestWaterBody?.size ?? .medium
        )
        
        switch reflectionFactor {
        case 0.0..<0.05:
            return .low
        case 0.05..<0.10:
            return .moderate
        case 0.10..<0.15:
            return .high
        case 0.15...:
            return .extreme
        default:
            return .low
        }
    }
    
    // MARK: - Water Risk Levels
    
    enum WaterRiskLevel: String, CaseIterable {
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
            case .none: return "No water nearby"
            case .low: return "Minimal water reflection"
            case .moderate: return "Moderate water reflection"
            case .high: return "High water reflection - take extra precautions"
            case .extreme: return "Extreme water reflection - maximum protection needed"
            }
        }
        
        var uvIncrease: String {
            switch self {
            case .none: return "0%"
            case .low: return "0-5%"
            case .moderate: return "5-10%"
            case .high: return "10-15%"
            case .extreme: return "15%+"
            }
        }
    }
    
    // MARK: - Water Data Fetching
    
    /// Fetch water proximity data for a location
    static func fetchWaterProximity(for location: CLLocation) async -> WaterProximity {
        // Note: This is a simplified implementation
        // In a real app, you'd use:
        // - OpenStreetMap API
        // - Google Places API
        // - Natural Earth Data
        // - Custom water body database
        
        let waterBody = await findNearestWaterBody(to: location)
        let distance = waterBody != nil ? calculateDistanceToWater(from: location, to: waterBody!) : Double.infinity
        let isCoastal = isCoastalLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        return WaterProximity(
            nearestWaterBody: waterBody,
            distanceToWater: distance,
            waterBodyType: waterBody?.type ?? .none,
            isCoastal: isCoastal,
            coastalDistance: isCoastal ? Double.random(in: 100...5000) : nil
        )
    }
    
    /// Find nearest water body to location (placeholder implementation)
    private static func findNearestWaterBody(to location: CLLocation) async -> WaterProximity.WaterBody? {
        // This is a simplified simulation
        // In a real app, you'd query a water body database
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Simulate finding water bodies based on location
        let waterBodies = await generateSimulatedWaterBodies(near: location)
        
        // Find the closest one
        var nearestWaterBody: WaterProximity.WaterBody?
        var shortestDistance = Double.infinity
        
        for waterBody in waterBodies {
            let distance = calculateDistanceToWater(from: location, to: waterBody)
            if distance < shortestDistance {
                shortestDistance = distance
                nearestWaterBody = waterBody
            }
        }
        
        return nearestWaterBody
    }
    
    /// Generate simulated water bodies for testing (placeholder)
    private static func generateSimulatedWaterBodies(near location: CLLocation) async -> [WaterProximity.WaterBody] {
        // This simulates finding water bodies
        // In a real app, this would be actual data
        
        var waterBodies: [WaterProximity.WaterBody] = []
        
        // Simulate some nearby water bodies
        let nearbyWaterTypes: [WaterProximity.WaterBodyType] = [.lake, .river, .pond, .stream]
        let nearbySizes: [WaterProximity.WaterBodySize] = [.small, .medium, .large]
        
        for i in 0..<Int.random(in: 0...3) {
            let waterType = nearbyWaterTypes.randomElement() ?? .lake
            let size = nearbySizes.randomElement() ?? .medium
            
            // Generate coordinates within ~10km
            let latOffset = Double.random(in: -0.1...0.1)
            let lonOffset = Double.random(in: -0.1...0.1)
            
            let waterLocation = CLLocationCoordinate2D(
                latitude: location.coordinate.latitude + latOffset,
                longitude: location.coordinate.longitude + lonOffset
            )
            
            let waterBody = WaterProximity.WaterBody(
                name: "\(waterType.rawValue) \(i + 1)",
                type: waterType,
                size: size,
                coordinates: waterLocation
            )
            
            waterBodies.append(waterBody)
        }
        
        return waterBodies
    }
    
    // MARK: - Water-Based Recommendations
    
    static func getWaterRecommendations(waterProximity: WaterProximity) -> [String] {
        let riskLevel = getWaterRiskLevel(waterProximity: waterProximity)
        
        var recommendations: [String] = []
        
        switch riskLevel {
        case .none:
            recommendations.append("No water nearby - normal UV protection")
            
        case .low:
            recommendations.append("Minimal water reflection - standard protection")
            recommendations.append("Apply sunscreen to exposed areas")
            
        case .moderate:
            recommendations.append("Moderate water reflection detected")
            recommendations.append("Use water-resistant sunscreen")
            recommendations.append("Reapply sunscreen after water activities")
            recommendations.append("Wear UV-protective sunglasses")
            
        case .high:
            recommendations.append("High water reflection - take extra precautions")
            recommendations.append("Use SPF 50+ water-resistant sunscreen")
            recommendations.append("Apply sunscreen every 1-2 hours")
            recommendations.append("Reapply after swimming or water activities")
            recommendations.append("Wear UV-protective clothing")
            recommendations.append("Seek shade when possible")
            
        case .extreme:
            recommendations.append("Extreme water reflection - maximum protection needed")
            recommendations.append("Use maximum SPF water-resistant protection")
            recommendations.append("Apply sunscreen every hour")
            recommendations.append("Wear UV-protective clothing and hat")
            recommendations.append("Limit time in direct sunlight")
            recommendations.append("Monitor for sunburn symptoms")
        }
        
        return recommendations
    }
    
    // MARK: - Water Education Content
    
    static func getWaterEducationContent(waterProximity: WaterProximity) -> String {
        let riskLevel = getWaterRiskLevel(waterProximity: waterProximity)
        
        switch riskLevel {
        case .none:
            return "No significant water bodies nearby. UV exposure is normal for current conditions."
            
        case .low:
            return "Small water bodies may reflect minimal UV rays. Standard sun protection is usually sufficient."
            
        case .moderate:
            return "Water reflects UV radiation, increasing your exposure. Large bodies of water can reflect up to 25% of UV rays, and the reflection can reach areas that would normally be shaded."
            
        case .high:
            return "Significant water reflection detected. Water can reflect substantial UV radiation, especially from large bodies like lakes and oceans. This reflection can cause sunburn even in shaded areas."
            
        case .extreme:
            return "Extreme water reflection conditions. Large bodies of water create significant UV reflection, and combined with direct UV exposure, can cause rapid sunburn. Maximum protection is essential."
        }
    }
    
    // MARK: - Water UI Helpers
    
    static func getWaterEmoji(waterProximity: WaterProximity) -> String {
        guard waterProximity.distanceToWater < 1000 else { return "🏞️" }
        
        switch waterProximity.waterBodyType {
        case .none:
            return "🏞️"
        case .ocean:
            return "🌊"
        case .sea:
            return "🌊"
        case .lake:
            return "🏞️"
        case .river:
            return "🌊"
        case .stream:
            return "💧"
        case .pond:
            return "🌊"
        case .pool:
            return "🏊"
        }
    }
    
    static func getWaterDescription(waterProximity: WaterProximity) -> String {
        guard waterProximity.distanceToWater < 1000 else { return "No water nearby" }
        
        let distance = formatDistance(waterProximity.distanceToWater)
        return "\(waterProximity.waterBodyType.rawValue) (\(distance) away)"
    }
    
    static func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000.0)
        } else {
            return "\(Int(distance)) m"
        }
    }
    
    static func getWaterBodyName(_ waterBody: WaterProximity.WaterBody?) -> String {
        return waterBody?.name ?? "Unknown"
    }
} 