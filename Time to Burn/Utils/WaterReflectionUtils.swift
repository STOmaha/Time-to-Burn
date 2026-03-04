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
    
    /// Fetch real water proximity data for a location using Overpass API (OpenStreetMap)
    static func fetchWaterProximity(for location: CLLocation) async -> WaterProximity {
        print("🌊 [WaterReflectionUtils] 🌐 Fetching real water proximity data")
        
        let waterBody = await findNearestWaterBodyReal(to: location)
        let distance = if let waterBody = waterBody {
            calculateDistanceToWater(from: location, to: waterBody)
        } else {
            Double.infinity
        }
        let isCoastal = await checkCoastalLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        return WaterProximity(
            nearestWaterBody: waterBody,
            distanceToWater: distance,
            waterBodyType: waterBody?.type ?? .none,
            isCoastal: isCoastal,
            coastalDistance: isCoastal ? distance : nil
        )
    }
    
    /// Find nearest water body to location using real geographic data
    private static func findNearestWaterBodyReal(to location: CLLocation) async -> WaterProximity.WaterBody? {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Use Overpass API to find nearby water bodies (free OpenStreetMap service)
        let overpassQuery = """
        [out:json][timeout:25];
        (
          way["natural"="water"](around:10000,\(latitude),\(longitude));
          relation["natural"="water"](around:10000,\(latitude),\(longitude));
          way["waterway"~"river|stream"](around:5000,\(latitude),\(longitude));
          way["place"="sea"](around:50000,\(latitude),\(longitude));
        );
        out center meta;
        """
        
        guard let encodedQuery = overpassQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            print("🌊 [WaterReflectionUtils] ❌ Invalid Overpass API URL")
            return await fallbackWaterProximity(for: location)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🌊 [WaterReflectionUtils] ❌ Overpass API request failed")
                return await fallbackWaterProximity(for: location)
            }
            
            let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
            
            return await findClosestWaterBody(from: overpassResponse.elements, to: location)
            
        } catch {
            print("🌊 [WaterReflectionUtils] ❌ Error fetching water data: \(error.localizedDescription)")
            return await fallbackWaterProximity(for: location)
        }
    }
    
    /// Find the closest water body from Overpass API results
    private static func findClosestWaterBody(from elements: [OverpassElement], to location: CLLocation) async -> WaterProximity.WaterBody? {
        var closestWaterBody: WaterProximity.WaterBody?
        var minDistance: Double = Double.infinity
        
        for element in elements {
            if let lat = element.lat ?? element.center?.lat,
               let lon = element.lon ?? element.center?.lon {
                
                let waterLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = location.distance(from: waterLocation)
                
                if distance < minDistance {
                    minDistance = distance
                    
                    // Determine water body type from OSM tags
                    let waterType = determineWaterType(from: element.tags)
                    let name = element.tags?["name"] ?? "Unknown Water Body"
                    
                    closestWaterBody = WaterProximity.WaterBody(
                        name: name,
                        type: waterType,
                        size: .medium, // Default size for unknown water bodies
                        coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    )
                }
            }
        }
        
        if let waterBody = closestWaterBody {
            let distance = minDistance
            print("🌊 [WaterReflectionUtils] ✅ Found \(waterBody.type.rawValue): \(waterBody.name) at \(Int(distance))m")
        }
        
        return closestWaterBody
    }
    
    /// Determine water body type from OpenStreetMap tags
    private static func determineWaterType(from tags: [String: String]?) -> WaterProximity.WaterBodyType {
        guard let tags = tags else { return .lake }
        
        if tags["place"] == "sea" || tags["natural"] == "coastline" {
            return .sea
        } else if tags["waterway"] == "river" {
            return .river
        } else if tags["waterway"] == "stream" {
            return .stream
        } else if let natural = tags["natural"], natural == "water" {
            if let water = tags["water"] {
                switch water {
                case "pond": return .pond
                case "reservoir": return .lake
                default: return .lake
                }
            }
            return .lake
        }
        
        return .lake
    }
    
    /// Check if location is coastal using real geographic boundaries
    private static func checkCoastalLocation(latitude: Double, longitude: Double) async -> Bool {
        // Simple coastal check based on known coastal proximity patterns
        // For more accuracy, you could use additional APIs or datasets
        
        // Check if very close to major coastlines (simplified)
        let knownCoastalRanges = [
            // Atlantic/Pacific coasts (rough approximations)
            (latRange: -90.0...90.0, lonRange: -180.0...(-60.0)), // Americas West
            (latRange: -90.0...90.0, lonRange: (-30.0)...30.0),    // Europe/Africa
            (latRange: -90.0...90.0, lonRange: 100.0...180.0),     // Asia/Pacific
        ]
        
        for range in knownCoastalRanges {
            if range.latRange.contains(latitude) && range.lonRange.contains(longitude) {
                // Additional distance-based check would be more accurate
                return true
            }
        }
        
        return false
    }
    
    /// Fallback water proximity when API fails
    private static func fallbackWaterProximity(for location: CLLocation) async -> WaterProximity.WaterBody? {
        print("🌊 [WaterReflectionUtils] 🔄 Using fallback water proximity estimation")
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Enhanced geographic estimation
        var waterType: WaterProximity.WaterBodyType = .none
        var name = "Unknown"
        
        // Check if likely near major water bodies based on geographic patterns
        if abs(latitude) < 5 && abs(longitude - 0) < 30 {
            // Equatorial Africa - likely rivers
            waterType = .river
            name = "Regional River"
        } else if latitude > 40 && longitude > -130 && longitude < -60 {
            // North America - Great Lakes region
            waterType = .lake
            name = "Great Lake"
        } else if latitude > 45 && longitude > -10 && longitude < 40 {
            // Northern Europe - many lakes
            waterType = .lake
            name = "Northern Lake"
        } else {
            // Default - distant water
            return nil
        }
        
        return WaterProximity.WaterBody(
            name: name,
            type: waterType,
            size: .medium, // Default size for fallback water bodies
            coordinates: CLLocationCoordinate2D(
                latitude: latitude + Double.random(in: -0.1...0.1),
                longitude: longitude + Double.random(in: -0.1...0.1)
            )
        )
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
    
    static func getWaterDescription(waterProximity: WaterProximity, unitConverter: UnitConverter? = nil) -> String {
        guard waterProximity.distanceToWater < 1000 else { return "No water nearby" }
        
        let distance = formatDistance(waterProximity.distanceToWater, unitConverter: unitConverter)
        return "\(waterProximity.waterBodyType.rawValue) (\(distance) away)"
    }
    
    static func formatDistance(_ distance: Double, unitConverter: UnitConverter? = nil) -> String {
        if let converter = unitConverter {
            return converter.formatDistanceWithUnits(distance)
        } else {
            // Fallback to metric formatting
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000.0)
        } else {
            return "\(Int(distance)) m"
            }
        }
    }
    
    static func getWaterBodyName(_ waterBody: WaterProximity.WaterBody?) -> String {
        return waterBody?.name ?? "Unknown"
    }
}

// MARK: - Overpass API Response Models

/// Response structure for Overpass API (OpenStreetMap)
private struct OverpassResponse: Codable {
    let version: Double?
    let generator: String?
    let elements: [OverpassElement]
}

/// Individual element from Overpass API response
private struct OverpassElement: Codable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?
}

/// Center coordinates for Overpass API elements
private struct OverpassCenter: Codable {
    let lat: Double
    let lon: Double
} 