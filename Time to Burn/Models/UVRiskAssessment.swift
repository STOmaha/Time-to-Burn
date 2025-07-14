import Foundation
import SwiftUI

// MARK: - UV Risk Assessment Model
struct UVRiskAssessment: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let baseUVIndex: Int
    let adjustedUVIndex: Int
    let riskScore: Double // 0.0 to 1.0
    let riskLevel: RiskLevel
    let riskFactors: [RiskFactor]
    let recommendations: [Recommendation]
    let environmentalFactors: EnvironmentalFactors
    
    init(
        baseUVIndex: Int,
        environmentalFactors: EnvironmentalFactors,
        riskFactors: [RiskFactor] = [],
        recommendations: [Recommendation] = []
    ) {
        self.timestamp = Date()
        self.baseUVIndex = baseUVIndex
        self.environmentalFactors = environmentalFactors
        self.riskFactors = riskFactors
        self.recommendations = recommendations
        
        // Calculate adjusted UV index and risk score
        let adjusted = UVRiskCalculator.calculateAdjustedUVIndex(
            baseUV: baseUVIndex,
            environmentalFactors: environmentalFactors
        )
        self.adjustedUVIndex = adjusted
        
        let risk = UVRiskCalculator.calculateRiskScore(
            adjustedUV: adjusted,
            environmentalFactors: environmentalFactors
        )
        self.riskScore = risk
        self.riskLevel = RiskLevel.fromScore(risk)
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp, baseUVIndex, adjustedUVIndex, riskScore, riskLevel, riskFactors, recommendations, environmentalFactors
    }
}

// MARK: - Risk Level
enum RiskLevel: String, Codable, CaseIterable {
    case veryLow = "Very Low"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
    case extreme = "Extreme"
    
    var color: Color {
        switch self {
        case .veryLow: return .green
        case .low: return .mint
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        case .extreme: return .purple
        }
    }
    
    var emoji: String {
        switch self {
        case .veryLow: return "🟢"
        case .low: return "🟢"
        case .moderate: return "🟡"
        case .high: return "🟠"
        case .veryHigh: return "🔴"
        case .extreme: return "🟣"
        }
    }
    
    var description: String {
        switch self {
        case .veryLow: return "Minimal UV risk - normal outdoor activities safe"
        case .low: return "Low UV risk - take basic precautions"
        case .moderate: return "Moderate UV risk - seek shade during peak hours"
        case .high: return "High UV risk - minimize sun exposure, use protection"
        case .veryHigh: return "Very high UV risk - avoid sun exposure"
        case .extreme: return "Extreme UV risk - stay indoors during peak hours"
        }
    }
    
    static func fromScore(_ score: Double) -> RiskLevel {
        switch score {
        case 0.0..<0.2: return .veryLow
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .moderate
        case 0.6..<0.8: return .high
        case 0.8..<0.9: return .veryHigh
        case 0.9...1.0: return .extreme
        default: return .moderate
        }
    }
}

// MARK: - Risk Factor
struct RiskFactor: Codable, Identifiable {
    let id = UUID()
    let type: RiskFactorType
    let severity: RiskSeverity
    let description: String
    let impact: Double // 0.0 to 1.0
    let mitigation: String
    
    enum RiskFactorType: String, Codable, CaseIterable {
        case altitude = "Altitude"
        case snowReflection = "Snow Reflection"
        case waterReflection = "Water Reflection"
        case cloudCover = "Cloud Cover"
        case terrain = "Terrain"
        case season = "Season"
        case timeOfDay = "Time of Day"
        case latitude = "Latitude"
        case pollution = "Air Pollution"
        case ozone = "Ozone Layer"
        
        var icon: String {
            switch self {
            case .altitude: return "mountain.2"
            case .snowReflection: return "snowflake"
            case .waterReflection: return "drop"
            case .cloudCover: return "cloud"
            case .terrain: return "map"
            case .season: return "leaf"
            case .timeOfDay: return "clock"
            case .latitude: return "location"
            case .pollution: return "smoke"
            case .ozone: return "sun.max"
            }
        }
    }
    
    enum RiskSeverity: String, Codable, CaseIterable {
        case none = "None"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case extreme = "Extreme"
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .extreme: return .red
            }
        }
    }
}

// MARK: - Recommendation
struct Recommendation: Codable, Identifiable {
    let id = UUID()
    let type: RecommendationType
    let priority: Priority
    let title: String
    let description: String
    let actionItems: [String]
    
    enum RecommendationType: String, Codable, CaseIterable {
        case sunscreen = "Sunscreen"
        case clothing = "Protective Clothing"
        case timing = "Timing"
        case shade = "Seek Shade"
        case hydration = "Hydration"
        case monitoring = "Monitoring"
        case avoidance = "Avoidance"
        case education = "Education"
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

// MARK: - UV Risk Calculator
struct UVRiskCalculator {
    
    // MARK: - Main Calculation Methods
    
    static func calculateAdjustedUVIndex(baseUV: Int, environmentalFactors: EnvironmentalFactors) -> Int {
        var adjustedUV = Double(baseUV)
        
        // Apply altitude multiplier
        adjustedUV *= calculateAltitudeMultiplier(altitude: environmentalFactors.altitude)
        
        // Apply cloud cover adjustment
        adjustedUV *= calculateCloudCoverMultiplier(cloudCover: environmentalFactors.snowConditions.snowCoverage)
        
        // Apply snow reflection
        adjustedUV *= calculateSnowReflectionMultiplier(snowConditions: environmentalFactors.snowConditions)
        
        // Apply water reflection
        adjustedUV *= calculateWaterReflectionMultiplier(waterProximity: environmentalFactors.waterProximity)
        
        // Apply terrain multiplier
        adjustedUV *= environmentalFactors.terrainType.altitudeMultiplier
        
        // Apply seasonal multiplier
        adjustedUV *= environmentalFactors.seasonalFactors.seasonalUVMultiplier
        
        return Int(round(adjustedUV))
    }
    
    static func calculateRiskScore(adjustedUV: Int, environmentalFactors: EnvironmentalFactors) -> Double {
        var riskScore = 0.0
        
        // Base UV risk (0.0 to 0.6)
        let baseRisk = min(Double(adjustedUV) / 11.0, 0.6) // Normalize to UV 11+ being 0.6
        riskScore += baseRisk
        
        // Environmental risk factors (0.0 to 0.4)
        let environmentalRisk = calculateEnvironmentalRiskScore(environmentalFactors)
        riskScore += environmentalRisk
        
        return min(riskScore, 1.0) // Cap at 1.0
    }
    
    // MARK: - Individual Factor Calculations
    
    private static func calculateAltitudeMultiplier(altitude: Double) -> Double {
        // UV increases by approximately 10% per 1000m elevation
        let altitudeInKm = altitude / 1000.0
        return 1.0 + (altitudeInKm * 0.1)
    }
    
    private static func calculateCloudCoverMultiplier(cloudCover: Double) -> Double {
        // Clouds don't block all UV - this is a common misconception
        // Even overcast conditions can still have significant UV
        switch cloudCover {
        case 0..<10: return 1.0 // Clear
        case 10..<25: return 0.95 // Mostly clear
        case 25..<50: return 0.85 // Partly cloudy
        case 50..<75: return 0.70 // Mostly cloudy
        case 75..<90: return 0.50 // Cloudy
        case 90...100: return 0.30 // Overcast
        default: return 1.0
        }
    }
    
    private static func calculateSnowReflectionMultiplier(snowConditions: SnowConditions) -> Double {
        guard snowConditions.snowCoverage > 0 else { return 1.0 }
        
        let reflectionFactor = snowConditions.snowType.reflectionFactor
        let coverageFactor = snowConditions.snowCoverage / 100.0
        
        // Calculate additional UV from snow reflection
        let additionalUV = reflectionFactor * coverageFactor * 0.8 // Max 80% additional UV
        
        return 1.0 + additionalUV
    }
    
    private static func calculateWaterReflectionMultiplier(waterProximity: WaterProximity) -> Double {
        guard waterProximity.distanceToWater < 1000 else { return 1.0 } // Only if within 1km
        
        let reflectionFactor = waterProximity.waterBodyType.reflectionFactor
        let sizeMultiplier = waterProximity.nearestWaterBody?.size.sizeMultiplier ?? 1.0
        
        // Distance factor (closer = more reflection)
        let distanceFactor = max(0.1, 1.0 - (waterProximity.distanceToWater / 1000.0))
        
        let additionalUV = reflectionFactor * sizeMultiplier * distanceFactor * 0.25 // Max 25% additional UV
        
        return 1.0 + additionalUV
    }
    
    private static func calculateEnvironmentalRiskScore(_ factors: EnvironmentalFactors) -> Double {
        var riskScore = 0.0
        
        // Altitude risk (0.0 to 0.1)
        let altitudeRisk = min(factors.altitude / 5000.0, 0.1) // Max risk at 5000m
        riskScore += altitudeRisk
        
        // Snow risk (0.0 to 0.15)
        if factors.snowConditions.snowCoverage > 0 {
            let snowRisk = (factors.snowConditions.snowCoverage / 100.0) * 0.15
            riskScore += snowRisk
        }
        
        // Water risk (0.0 to 0.1)
        if factors.waterProximity.distanceToWater < 1000 {
            let waterRisk = max(0.0, (1000.0 - factors.waterProximity.distanceToWater) / 1000.0) * 0.1
            riskScore += waterRisk
        }
        
        // Terrain risk (0.0 to 0.05)
        let terrainRisk = (factors.terrainType.altitudeMultiplier - 1.0) * 0.25
        riskScore += max(0.0, terrainRisk)
        
        return min(riskScore, 0.4) // Cap environmental risk at 0.4
    }
    
    // MARK: - Risk Factor Generation
    
    static func generateRiskFactors(assessment: UVRiskAssessment) -> [RiskFactor] {
        var factors: [RiskFactor] = []
        
        // Altitude factor
        if assessment.environmentalFactors.altitude > 1000 {
            let severity: RiskFactor.RiskSeverity = assessment.environmentalFactors.altitude > 3000 ? .high : .moderate
            factors.append(RiskFactor(
                type: .altitude,
                severity: severity,
                description: "Elevation of \(Int(assessment.environmentalFactors.altitude))m increases UV exposure",
                impact: min(assessment.environmentalFactors.altitude / 5000.0, 1.0),
                mitigation: "Take extra precautions at high altitudes"
            ))
        }
        
        // Snow reflection factor
        if assessment.environmentalFactors.snowConditions.snowCoverage > 0 {
            let severity: RiskFactor.RiskSeverity = assessment.environmentalFactors.snowConditions.snowType == .fresh ? .high : .moderate
            factors.append(RiskFactor(
                type: .snowReflection,
                severity: severity,
                description: "\(assessment.environmentalFactors.snowConditions.snowType.rawValue) snow reflects up to \(Int(assessment.environmentalFactors.snowConditions.snowType.reflectionFactor * 100))% of UV",
                impact: assessment.environmentalFactors.snowConditions.snowCoverage / 100.0,
                mitigation: "Wear UV-protective eyewear and apply sunscreen to exposed areas"
            ))
        }
        
        // Water reflection factor
        if assessment.environmentalFactors.waterProximity.distanceToWater < 1000 {
            factors.append(RiskFactor(
                type: .waterReflection,
                severity: .moderate,
                description: "Nearby \(assessment.environmentalFactors.waterProximity.waterBodyType.rawValue.lowercased()) reflects UV",
                impact: 0.3,
                mitigation: "Apply sunscreen more frequently when near water"
            ))
        }
        
        // Cloud cover factor (educational)
        if assessment.environmentalFactors.snowConditions.snowCoverage > 50 {
            factors.append(RiskFactor(
                type: .cloudCover,
                severity: .low,
                description: "Clouds don't block all UV rays - protection still needed",
                impact: 0.1,
                mitigation: "Don't rely on clouds for UV protection"
            ))
        }
        
        return factors
    }
    
    // MARK: - Recommendation Generation
    
    static func generateRecommendations(assessment: UVRiskAssessment) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Base recommendations based on risk level
        switch assessment.riskLevel {
        case .veryLow, .low:
            recommendations.append(Recommendation(
                type: .sunscreen,
                priority: .low,
                title: "Basic Sun Protection",
                description: "Apply SPF 30+ sunscreen for extended outdoor activities",
                actionItems: ["Apply sunscreen 15 minutes before going outside", "Reapply every 2 hours", "Use water-resistant formula if swimming"]
            ))
            
        case .moderate:
            recommendations.append(Recommendation(
                type: .timing,
                priority: .medium,
                title: "Avoid Peak Hours",
                description: "Limit outdoor activities during peak UV hours (10 AM - 4 PM)",
                actionItems: ["Seek shade during peak hours", "Wear protective clothing", "Apply SPF 50+ sunscreen"]
            ))
            
        case .high:
            recommendations.append(Recommendation(
                type: .avoidance,
                priority: .high,
                title: "Minimize Sun Exposure",
                description: "High UV risk - take extra precautions",
                actionItems: ["Stay in shade when possible", "Wear wide-brimmed hat", "Use SPF 50+ sunscreen", "Wear UV-protective clothing"]
            ))
            
        case .veryHigh, .extreme:
            recommendations.append(Recommendation(
                type: .avoidance,
                priority: .critical,
                title: "Extreme UV Risk",
                description: "Avoid outdoor activities during peak hours",
                actionItems: ["Stay indoors during peak hours", "If outside, seek shade constantly", "Wear maximum protection", "Monitor for sunburn symptoms"]
            ))
        }
        
        // Environmental-specific recommendations
        if assessment.environmentalFactors.altitude > 2000 {
            recommendations.append(Recommendation(
                type: .education,
                priority: .high,
                title: "High Altitude Warning",
                description: "UV intensity increases significantly at high altitudes",
                actionItems: ["Use higher SPF sunscreen", "Apply more frequently", "Wear UV-protective eyewear", "Stay hydrated"]
            ))
        }
        
        if assessment.environmentalFactors.snowConditions.snowCoverage > 0 {
            recommendations.append(Recommendation(
                type: .clothing,
                priority: .high,
                title: "Snow Reflection Protection",
                description: "Snow reflects UV rays, increasing exposure",
                actionItems: ["Wear UV-protective sunglasses", "Apply sunscreen to face and neck", "Cover exposed skin", "Use lip balm with SPF"]
            ))
        }
        
        if assessment.environmentalFactors.waterProximity.distanceToWater < 500 {
            recommendations.append(Recommendation(
                type: .sunscreen,
                priority: .medium,
                title: "Water Reflection Protection",
                description: "Water reflects UV rays, requiring extra protection",
                actionItems: ["Use water-resistant sunscreen", "Reapply after swimming", "Wear protective clothing", "Seek shade when possible"]
            ))
        }
        
        return recommendations
    }
} 