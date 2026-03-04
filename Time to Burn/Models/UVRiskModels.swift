import Foundation
import SwiftUI

// MARK: - UV Risk Assessment Models

/// Comprehensive UV risk level with actionable guidance
struct UVRiskLevel {
    let level: RiskCategory
    let description: String
    let color: Color
    let emoji: String
    let actionRequired: Bool
    
    enum RiskCategory: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        case extreme = "Extreme"
        
        var priority: Int {
            switch self {
            case .low: return 0
            case .moderate: return 1
            case .high: return 2
            case .veryHigh: return 3
            case .extreme: return 4
            }
        }
    }
}

/// Sun protection guidance with specific time ranges
struct SunProtectionGuidance {
    let sunscreenRequired: TimeRange?
    let seekShadeRequired: TimeRange?
    let avoidSunRequired: TimeRange?
    let recommendations: [String]
    
    struct TimeRange {
        let start: Date
        let end: Date
        
        var formattedRange: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        
        var isActive: Bool {
            let now = Date()
            return now >= start && now <= end
        }
    }
}

/// Misery index combining multiple weather factors
struct MiseryIndex {
    let value: Double // 0-100 scale
    let level: MiseryLevel
    let factors: [MiseryFactor]
    let warning: String?
    
    enum MiseryLevel: String, CaseIterable {
        case pleasant = "Pleasant"
        case comfortable = "Comfortable"
        case noticeable = "Noticeable"
        case uncomfortable = "Uncomfortable"
        case oppressive = "Oppressive"
        case dangerous = "Dangerous"
        case extreme = "Extreme"
        
        var color: Color {
            switch self {
            case .pleasant: return .green
            case .comfortable: return .blue
            case .noticeable: return .yellow
            case .uncomfortable: return .orange
            case .oppressive: return .red
            case .dangerous: return .purple
            case .extreme: return .black
            }
        }
        
        var emoji: String {
            switch self {
            case .pleasant: return "😊"
            case .comfortable: return "🙂"
            case .noticeable: return "😐"
            case .uncomfortable: return "😰"
            case .oppressive: return "🥵"
            case .dangerous: return "⚠️"
            case .extreme: return "☠️"
            }
        }
    }
    
    struct MiseryFactor {
        let type: FactorType
        let value: Double
        let impact: Impact
        let description: String
        
        enum FactorType {
            case uv
            case temperature
            case humidity
            case wind
            case heatIndex
        }
        
        enum Impact: String {
            case minimal = "Minimal"
            case low = "Low"
            case moderate = "Moderate"
            case high = "High"
            case severe = "Severe"
            case extreme = "Extreme"
            
            var color: Color {
                switch self {
                case .minimal: return .green
                case .low: return .blue
                case .moderate: return .yellow
                case .high: return .orange
                case .severe: return .red
                case .extreme: return .purple
                }
            }
        }
    }
}

/// Complete UV risk display model combining all factors for UI
struct UVRiskDisplayModel {
    let timestamp: Date
    let uvIndex: Int
    let riskLevel: UVRiskLevel
    let protectionGuidance: SunProtectionGuidance
    let miseryIndex: MiseryIndex
    let overallRecommendation: String
    let criticalWarning: String?
    
    /// Determines if immediate action is required
    var requiresImmediateAction: Bool {
        return riskLevel.actionRequired || 
               miseryIndex.level == .dangerous || 
               miseryIndex.level == .extreme ||
               criticalWarning != nil
    }
    
    /// Gets the highest priority guidance to display
    var primaryGuidance: String {
        if let warning = criticalWarning {
            return warning
        }
        
        if let avoidSun = protectionGuidance.avoidSunRequired, avoidSun.isActive {
            return "🚫 Avoid sun exposure now (\(avoidSun.formattedRange))"
        }
        
        if let seekShade = protectionGuidance.seekShadeRequired, seekShade.isActive {
            return "🌳 Seek shade (\(seekShade.formattedRange))"
        }
        
        if let sunscreen = protectionGuidance.sunscreenRequired, sunscreen.isActive {
            return "🧴 Apply sunscreen (\(sunscreen.formattedRange))"
        }
        
        return overallRecommendation
    }
}

// MARK: - Risk Level Definitions

extension UVRiskLevel {
    static func forUVIndex(_ uvIndex: Int) -> UVRiskLevel {
        switch uvIndex {
        case 0...2:
            return UVRiskLevel(
                level: .low,
                description: "Minimal protection needed. Safe for most outdoor activities.",
                color: .green,
                emoji: "✅",
                actionRequired: false
            )
        case 3...5:
            return UVRiskLevel(
                level: .moderate,
                description: "Stay in shade during midday hours. Wear sun protection.",
                color: .yellow,
                emoji: "⚠️",
                actionRequired: true
            )
        case 6...7:
            return UVRiskLevel(
                level: .high,
                description: "Protection required. Avoid sun during peak hours.",
                color: .orange,
                emoji: "🔶",
                actionRequired: true
            )
        case 8...10:
            return UVRiskLevel(
                level: .veryHigh,
                description: "Extra protection essential. Minimize outdoor time.",
                color: .red,
                emoji: "🔴",
                actionRequired: true
            )
        default: // 11+ (includes 12+ extreme levels)
            return UVRiskLevel(
                level: .extreme,
                description: "EXTREME - Stay indoors. Sunburn risk in under 5 minutes.",
                color: .purple,
                emoji: "☠️",
                actionRequired: true
            )
        }
    }
}
