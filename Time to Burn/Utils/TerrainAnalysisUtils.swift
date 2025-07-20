import Foundation
import CoreLocation

struct TerrainAnalysisUtils {
    
    // MARK: - Terrain Analysis
    
    /// Analyze terrain type based on location and environmental factors
    static func analyzeTerrainType(location: CLLocation, altitude: Double, waterProximity: WaterProximity) -> TerrainType {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Check for coastal areas
        if waterProximity.isCoastal || waterProximity.distanceToWater < 500 {
            return .coastal
        }
        
        // Check for mountainous terrain
        if altitude > 1000 {
            return .mountainous
        }
        
        // Check for arctic regions
        if abs(latitude) > 60 {
            return .arctic
        }
        
        // Check for desert regions
        if isDesertRegion(latitude: latitude, longitude: longitude) {
            return .desert
        }
        
        // Check for forest regions
        if isForestRegion(latitude: latitude, longitude: longitude) {
            return .forest
        }
        
        // Check for urban areas (simplified)
        if isUrbanArea(latitude: latitude, longitude: longitude) {
            return .urban
        }
        
        // Default to rural
        return .rural
    }
    
    /// Determine if location is in a desert region
    private static func isDesertRegion(latitude: Double, longitude: Double) -> Bool {
        // Simplified desert detection based on major desert regions
        let deserts = [
            // Sahara Desert
            (latitude: 15.0...35.0, longitude: -20.0...40.0),
            // Arabian Desert
            (latitude: 15.0...35.0, longitude: 35.0...60.0),
            // Gobi Desert
            (latitude: 35.0...50.0, longitude: 85.0...120.0),
            // Mojave Desert
            (latitude: 32.0...38.0, longitude: (-118.0)...(-114.0)),
            // Sonoran Desert
            (latitude: 25.0...35.0, longitude: (-118.0)...(-105.0)),
            // Australian Outback
            (latitude: (-25.0)...(-15.0), longitude: 115.0...145.0)
        ]
        
        for desert in deserts {
            if desert.latitude.contains(latitude) && desert.longitude.contains(longitude) {
                return true
            }
        }
        
        return false
    }
    
    /// Determine if location is in a forest region
    private static func isForestRegion(latitude: Double, longitude: Double) -> Bool {
        // Simplified forest detection based on major forest regions
        let forests = [
            // Amazon Rainforest
            (latitude: (-10.0)...5.0, longitude: (-80.0)...(-50.0)),
            // Boreal Forest (North America)
            (latitude: 45.0...70.0, longitude: (-140.0)...(-60.0)),
            // Boreal Forest (Eurasia)
            (latitude: 45.0...70.0, longitude: 20.0...180.0),
            // Congo Rainforest
            (latitude: (-5.0)...5.0, longitude: 10.0...30.0),
            // Southeast Asian Rainforest
            (latitude: (-10.0)...20.0, longitude: 90.0...130.0)
        ]
        
        for forest in forests {
            if forest.latitude.contains(latitude) && forest.longitude.contains(longitude) {
                return true
            }
        }
        
        return false
    }
    
    /// Determine if location is in an urban area
    private static func isUrbanArea(latitude: Double, longitude: Double) -> Bool {
        // This is a very simplified urban detection
        // In a real app, you'd use population density data or city databases
        
        // Major urban areas (simplified)
        let urbanAreas = [
            // North America
            (latitude: 40.0...45.0, longitude: (-80.0)...(-70.0)), // NYC area
            (latitude: 34.0...35.0, longitude: (-119.0)...(-118.0)), // LA area
            (latitude: 41.0...42.0, longitude: (-88.0)...(-87.0)), // Chicago area
            // Europe
            (latitude: 48.0...53.0, longitude: (-5.0)...15.0), // Western Europe
            // Asia
            (latitude: 35.0...40.0, longitude: 135.0...140.0), // Tokyo area
            (latitude: 22.0...23.0, longitude: 113.0...114.0), // Hong Kong area
        ]
        
        for urbanArea in urbanAreas {
            if urbanArea.latitude.contains(latitude) && urbanArea.longitude.contains(longitude) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Terrain Risk Assessment
    
    /// Get terrain risk level
    static func getTerrainRiskLevel(terrainType: TerrainType) -> TerrainRiskLevel {
        switch terrainType {
        case .unknown:
            return .unknown
        case .coastal:
            return .moderate
        case .mountainous:
            return .high
        case .urban:
            return .low
        case .rural:
            return .low
        case .desert:
            return .high
        case .forest:
            return .low
        case .grassland:
            return .moderate
        case .arctic:
            return .extreme
        }
    }
    
    /// Calculate terrain UV multiplier
    static func calculateTerrainUVMultiplier(terrainType: TerrainType, altitude: Double) -> Double {
        var multiplier = terrainType.altitudeMultiplier
        
        // Additional altitude effect for mountainous terrain
        if terrainType == .mountainous && altitude > 2000 {
            multiplier *= 1.1
        }
        
        // Additional effect for arctic terrain
        if terrainType == .arctic {
            multiplier *= 1.2 // Snow reflection effect
        }
        
        return multiplier
    }
    
    // MARK: - Terrain Risk Levels
    
    enum TerrainRiskLevel: String, CaseIterable {
        case unknown = "Unknown"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case extreme = "Extreme"
        
        var color: String {
            switch self {
            case .unknown: return "gray"
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .extreme: return "red"
            }
        }
        
        var description: String {
            switch self {
            case .unknown: return "Terrain type unknown"
            case .low: return "Low terrain UV risk"
            case .moderate: return "Moderate terrain UV risk"
            case .high: return "High terrain UV risk"
            case .extreme: return "Extreme terrain UV risk"
            }
        }
        
        var uvEffect: String {
            switch self {
            case .unknown: return "Unknown"
            case .low: return "Reduced UV exposure"
            case .moderate: return "Slight UV increase"
            case .high: return "Significant UV increase"
            case .extreme: return "Maximum UV exposure"
            }
        }
    }
    
    // MARK: - Terrain Data Fetching
    
    /// Fetch terrain data for a location
    static func fetchTerrainData(for location: CLLocation, altitude: Double, waterProximity: WaterProximity) async -> TerrainData {
        let terrainType = analyzeTerrainType(location: location, altitude: altitude, waterProximity: waterProximity)
        let riskLevel = getTerrainRiskLevel(terrainType: terrainType)
        let uvMultiplier = calculateTerrainUVMultiplier(terrainType: terrainType, altitude: altitude)
        
        return TerrainData(
            terrainType: terrainType,
            riskLevel: riskLevel,
            uvMultiplier: uvMultiplier,
            description: getTerrainDescription(terrainType: terrainType, altitude: altitude),
            recommendations: getTerrainRecommendations(terrainType: terrainType, altitude: altitude)
        )
    }
    
    // MARK: - Terrain Data Model
    
    struct TerrainData {
        let terrainType: TerrainType
        let riskLevel: TerrainRiskLevel
        let uvMultiplier: Double
        let description: String
        let recommendations: [String]
    }
    
    // MARK: - Terrain Descriptions
    
    static func getTerrainDescription(terrainType: TerrainType, altitude: Double) -> String {
        switch terrainType {
        case .unknown:
            return "Terrain type unknown"
        case .coastal:
            return "Coastal area - water reflection increases UV exposure"
        case .mountainous:
            return "Mountainous terrain at \(Int(altitude))m - altitude significantly increases UV exposure"
        case .urban:
            return "Urban area - buildings may provide some shade but UV exposure can still be high"
        case .rural:
            return "Rural area - open exposure to sunlight"
        case .desert:
            return "Desert terrain - sand reflection and intense sunlight create high UV exposure"
        case .forest:
            return "Forest area - tree cover may reduce UV exposure"
        case .grassland:
            return "Grassland - open exposure to sunlight"
        case .arctic:
            return "Arctic terrain - snow reflection and altitude create extreme UV conditions"
        }
    }
    
    // MARK: - Terrain-Based Recommendations
    
    static func getTerrainRecommendations(terrainType: TerrainType, altitude: Double) -> [String] {
        var recommendations: [String] = []
        
        switch terrainType {
        case .unknown:
            recommendations.append("Terrain type unknown - use standard UV protection")
            
        case .coastal:
            recommendations.append("Coastal area - water reflects UV rays")
            recommendations.append("Use water-resistant sunscreen")
            recommendations.append("Reapply sunscreen after water activities")
            recommendations.append("Be aware of reflected UV in shaded areas")
            
        case .mountainous:
            recommendations.append("High altitude - UV increases with elevation")
            recommendations.append("Use SPF 50+ sunscreen")
            recommendations.append("Apply sunscreen every 1-2 hours")
            recommendations.append("Wear UV-protective eyewear")
            recommendations.append("Stay hydrated")
            if altitude > 3000 {
                recommendations.append("Extreme altitude - consider postponing outdoor activities")
            }
            
        case .urban:
            recommendations.append("Urban area - buildings may provide shade")
            recommendations.append("Use standard UV protection")
            recommendations.append("Be aware of reflected UV from buildings")
            
        case .rural:
            recommendations.append("Rural area - open exposure to sunlight")
            recommendations.append("Use standard UV protection")
            recommendations.append("Seek shade when possible")
            
        case .desert:
            recommendations.append("Desert terrain - extreme UV conditions")
            recommendations.append("Use maximum SPF protection")
            recommendations.append("Wear protective clothing")
            recommendations.append("Stay hydrated")
            recommendations.append("Limit outdoor activities during peak hours")
            recommendations.append("Be aware of sand reflection")
            
        case .forest:
            recommendations.append("Forest area - tree cover may reduce UV")
            recommendations.append("Use standard UV protection")
            recommendations.append("Be aware of UV exposure in clearings")
            
        case .grassland:
            recommendations.append("Grassland - open exposure to sunlight")
            recommendations.append("Use standard UV protection")
            recommendations.append("Seek shade when possible")
            
        case .arctic:
            recommendations.append("Arctic terrain - extreme UV conditions")
            recommendations.append("Use maximum SPF protection")
            recommendations.append("Wear UV-protective eyewear")
            recommendations.append("Cover all exposed skin")
            recommendations.append("Be aware of snow reflection")
            recommendations.append("Monitor for sunburn symptoms")
        }
        
        return recommendations
    }
    
    // MARK: - Terrain Education Content
    
    static func getTerrainEducationContent(terrainType: TerrainType, altitude: Double) -> String {
        switch terrainType {
        case .unknown:
            return "Terrain type could not be determined. Use standard UV protection measures."
            
        case .coastal:
            return "Coastal areas experience increased UV exposure due to water reflection. Water can reflect up to 25% of UV radiation, and this reflection can reach areas that would normally be shaded."
            
        case .mountainous:
            return "Mountainous terrain creates significantly higher UV exposure. UV intensity increases by approximately 10% per 1000m elevation due to thinner atmosphere. Combined with potential snow reflection, this can create extreme UV conditions."
            
        case .urban:
            return "Urban areas may provide some shade from buildings, but UV exposure can still be significant. Reflected UV from buildings and pavement can increase exposure, especially during peak hours."
            
        case .rural:
            return "Rural areas typically have open exposure to sunlight with minimal obstruction. Standard UV protection measures are appropriate for these conditions."
            
        case .desert:
            return "Desert terrain creates extreme UV conditions due to intense sunlight and sand reflection. Sand can reflect up to 20% of UV radiation, and the combination of direct and reflected UV can cause rapid sunburn."
            
        case .forest:
            return "Forest areas may provide some UV protection through tree cover, but exposure can still be significant in clearings or during peak hours. UV exposure varies based on canopy density."
            
        case .grassland:
            return "Grassland areas provide open exposure to sunlight with minimal natural shade. Standard UV protection measures are appropriate for these conditions."
            
        case .arctic:
            return "Arctic terrain creates the most extreme UV conditions possible. The combination of high altitude, snow reflection (up to 80%), and long daylight hours during summer creates maximum UV exposure."
        }
    }
    
    // MARK: - Terrain UI Helpers
    
    static func getTerrainEmoji(terrainType: TerrainType) -> String {
        switch terrainType {
        case .unknown:
            return "❓"
        case .coastal:
            return "🏖️"
        case .mountainous:
            return "🏔️"
        case .urban:
            return "🏙️"
        case .rural:
            return "🌾"
        case .desert:
            return "🏜️"
        case .forest:
            return "🌲"
        case .grassland:
            return "🌾"
        case .arctic:
            return "❄️"
        }
    }
    
    static func getTerrainColor(terrainType: TerrainType) -> String {
        switch terrainType {
        case .unknown:
            return "gray"
        case .coastal:
            return "blue"
        case .mountainous:
            return "brown"
        case .urban:
            return "gray"
        case .rural:
            return "green"
        case .desert:
            return "yellow"
        case .forest:
            return "green"
        case .grassland:
            return "green"
        case .arctic:
            return "white"
        }
    }
} 