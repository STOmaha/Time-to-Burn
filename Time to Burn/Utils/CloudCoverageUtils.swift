import SwiftUI

struct CloudCoverageUtils {
    
    // MARK: - Cloud Coverage Categories
    
    enum CloudCategory: String, CaseIterable {
        case clear = "Clear"
        case mostlyClear = "Mostly Clear"
        case partlyCloudy = "Partly Cloudy"
        case mostlyCloudy = "Mostly Cloudy"
        case cloudy = "Cloudy"
        case overcast = "Overcast"
        
        var icon: String {
            switch self {
            case .clear:
                return "sun.max.fill"
            case .mostlyClear:
                return "sun.max"
            case .partlyCloudy:
                return "cloud.sun.fill"
            case .mostlyCloudy:
                return "cloud.sun"
            case .cloudy:
                return "cloud.fill"
            case .overcast:
                return "cloud.rain.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .clear:
                return .yellow
            case .mostlyClear:
                return .orange
            case .partlyCloudy:
                return .blue
            case .mostlyCloudy:
                return .gray
            case .cloudy:
                return .secondary
            case .overcast:
                return .primary
            }
        }
        
        var description: String {
            switch self {
            case .clear:
                return "Clear skies - maximum UV exposure"
            case .mostlyClear:
                return "Mostly clear - high UV exposure"
            case .partlyCloudy:
                return "Partly cloudy - moderate UV exposure"
            case .mostlyCloudy:
                return "Mostly cloudy - reduced UV exposure"
            case .cloudy:
                return "Cloudy - significantly reduced UV"
            case .overcast:
                return "Overcast - minimal UV exposure"
            }
        }
    }
    
    // MARK: - Cloud Coverage Calculations
    
    static func getCloudCategory(from cloudCover: Double) -> CloudCategory {
        switch cloudCover {
        case 0..<10:
            return .clear
        case 10..<25:
            return .mostlyClear
        case 25..<50:
            return .partlyCloudy
        case 50..<75:
            return .mostlyCloudy
        case 75..<90:
            return .cloudy
        case 90...100:
            return .overcast
        default:
            return .clear
        }
    }
    
    static func getUVReductionFactor(cloudCover: Double) -> Double {
        // Calculate how much clouds reduce UV exposure
        // This is a simplified model - actual UV reduction varies by cloud type and thickness
        switch cloudCover {
        case 0..<10:
            return 1.0 // No reduction
        case 10..<25:
            return 0.95 // 5% reduction
        case 25..<50:
            return 0.85 // 15% reduction
        case 50..<75:
            return 0.70 // 30% reduction
        case 75..<90:
            return 0.50 // 50% reduction
        case 90...100:
            return 0.30 // 70% reduction
        default:
            return 1.0
        }
    }
    
    static func getAdjustedUVIndex(baseUV: Int, cloudCover: Double) -> Int {
        let reductionFactor = getUVReductionFactor(cloudCover: cloudCover)
        return Int(Double(baseUV) * reductionFactor)
    }
    
    // MARK: - Display Functions
    
    static func formatCloudCover(_ cloudCover: Double) -> String {
        return "\(Int(cloudCover))%"
    }
    
    static func getCloudCoverDescription(_ cloudCover: Double) -> String {
        let category = getCloudCategory(from: cloudCover)
        return "\(category.rawValue) (\(formatCloudCover(cloudCover)))"
    }
    
    static func getCloudCoverEmoji(_ cloudCover: Double) -> String {
        let category = getCloudCategory(from: cloudCover)
        switch category {
        case .clear:
            return "☀️"
        case .mostlyClear:
            return "🌤️"
        case .partlyCloudy:
            return "⛅"
        case .mostlyCloudy:
            return "🌥️"
        case .cloudy:
            return "☁️"
        case .overcast:
            return "🌧️"
        }
    }
    
    // MARK: - UV Protection Impact
    
    static func getUVProtectionImpact(cloudCover: Double) -> String {
        let reductionFactor = getUVReductionFactor(cloudCover: cloudCover)
        let reductionPercent = Int((1.0 - reductionFactor) * 100)
        
        if reductionPercent == 0 {
            return "No UV reduction"
        } else if reductionPercent < 20 {
            return "Minimal UV reduction (\(reductionPercent)%)"
        } else if reductionPercent < 50 {
            return "Moderate UV reduction (\(reductionPercent)%)"
        } else {
            return "Significant UV reduction (\(reductionPercent)%)"
        }
    }
} 