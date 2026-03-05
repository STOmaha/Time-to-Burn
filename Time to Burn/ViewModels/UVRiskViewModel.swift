import Foundation
import SwiftUI
import WeatherKit
import Combine

// MARK: - UV Risk Assessment ViewModel

@MainActor
class UVRiskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentRiskAssessment: UVRiskDisplayModel?
    @Published var isCalculating = false
    @Published var lastCalculated: Date?
    
    // MARK: - Dependencies
    private var weatherViewModel: WeatherViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let riskCalculationSettings = RiskCalculationSettings()
    
    init() {
        print("🎯 [UVRiskViewModel] Initializing risk assessment system")
    }

    deinit {
        // Cancel all Combine subscriptions to prevent memory leaks
        cancellables.removeAll()
    }

    // MARK: - Setup
    func configure(with weatherViewModel: WeatherViewModel) {
        self.weatherViewModel = weatherViewModel
        
        // Listen for weather data changes
        weatherViewModel.$currentUVData
            .sink { [weak self] _ in
                Task {
                    await self?.calculateRiskAssessment()
                }
            }
            .store(in: &cancellables)
        
        weatherViewModel.$lastUpdated
            .sink { [weak self] _ in
                Task {
                    await self?.calculateRiskAssessment()
                }
            }
            .store(in: &cancellables)
        
        print("🎯 [UVRiskViewModel] Configured with WeatherViewModel")
    }
    
    // MARK: - Risk Assessment Calculation
    
    func calculateRiskAssessment() async {
        guard let weatherViewModel = weatherViewModel,
              let uvData = weatherViewModel.currentUVData else {
            print("🎯 [UVRiskViewModel] No weather data available for risk assessment")
            return
        }
        
        isCalculating = true
        
        // Calculate each component
        let riskLevel = calculateUVRiskLevel(uvIndex: uvData.uvIndex)
        let protectionGuidance = await calculateProtectionGuidance(weatherViewModel: weatherViewModel)
        let miseryIndex = calculateMiseryIndex(weatherViewModel: weatherViewModel)
        
        // Generate overall recommendation
        let overallRecommendation = generateOverallRecommendation(
            riskLevel: riskLevel,
            miseryIndex: miseryIndex
        )
        
        // Check for critical warnings
        let criticalWarning = generateCriticalWarning(
            uvIndex: uvData.uvIndex,
            miseryIndex: miseryIndex
        )
        
        // Create comprehensive assessment
        let assessment = UVRiskDisplayModel(
            timestamp: Date(),
            uvIndex: uvData.uvIndex,
            riskLevel: riskLevel,
            protectionGuidance: protectionGuidance,
            miseryIndex: miseryIndex,
            overallRecommendation: overallRecommendation,
            criticalWarning: criticalWarning
        )
        
        currentRiskAssessment = assessment
        lastCalculated = Date()
        
        print("🎯 [UVRiskViewModel] Risk assessment calculated - UV: \(uvData.uvIndex), Risk: \(riskLevel.level.rawValue), Misery: \(miseryIndex.level.rawValue)")
        
        isCalculating = false
    }
    
    // MARK: - UV Risk Level Calculation
    
    private func calculateUVRiskLevel(uvIndex: Int) -> UVRiskLevel {
        return UVRiskLevel.forUVIndex(uvIndex)
    }
    
    // MARK: - Protection Guidance Calculation
    
    private func calculateProtectionGuidance(weatherViewModel: WeatherViewModel) async -> SunProtectionGuidance {
        guard weatherViewModel.currentUVData != nil else {
            return SunProtectionGuidance(
                sunscreenRequired: nil,
                seekShadeRequired: nil,
                avoidSunRequired: nil,
                recommendations: ["No weather data available"]
            )
        }
        
        // Calculate critical UV hours from hourly data
        let criticalHours = getCriticalUVHours(from: weatherViewModel.hourlyUVData)
        
        var recommendations: [String] = []
        var sunscreenRange: SunProtectionGuidance.TimeRange?
        var shadeRange: SunProtectionGuidance.TimeRange?
        var avoidSunRange: SunProtectionGuidance.TimeRange?
        
        // Sunscreen recommendations (UV 3+)
        if let sunscreenHours = criticalHours.sunscreenHours {
            sunscreenRange = SunProtectionGuidance.TimeRange(
                start: sunscreenHours.start,
                end: sunscreenHours.end
            )
            recommendations.append("Apply broad-spectrum SPF 30+ sunscreen")
            recommendations.append("Reapply every 2 hours or after swimming/sweating")
        }
        
        // Shade recommendations (UV 6+)
        if let shadeHours = criticalHours.shadeHours {
            shadeRange = SunProtectionGuidance.TimeRange(
                start: shadeHours.start,
                end: shadeHours.end
            )
            recommendations.append("Seek shade during peak UV hours")
            recommendations.append("Wear protective clothing and wide-brimmed hat")
        }
        
        // Avoid sun recommendations (UV 12+)
        if let avoidHours = criticalHours.avoidSunHours {
            avoidSunRange = SunProtectionGuidance.TimeRange(
                start: avoidHours.start,
                end: avoidHours.end
            )
            recommendations.append("Stay indoors during extreme UV periods")
            recommendations.append("If outdoors, ensure complete sun protection")
        }
        
        return SunProtectionGuidance(
            sunscreenRequired: sunscreenRange,
            seekShadeRequired: shadeRange,
            avoidSunRequired: avoidSunRange,
            recommendations: recommendations
        )
    }
    
    // MARK: - Misery Index Calculation
    
    private func calculateMiseryIndex(weatherViewModel: WeatherViewModel) -> MiseryIndex {
        guard let uvData = weatherViewModel.currentUVData else {
            return MiseryIndex(
                value: 0,
                level: .pleasant,
                factors: [],
                warning: "No weather data available"
            )
        }
        
        var factors: [MiseryIndex.MiseryFactor] = []
        var totalScore: Double = 0
        var componentCount = 0
        
        // UV Factor (0-40 points)
        let uvScore = calculateUVMiseryScore(uvIndex: uvData.uvIndex)
        factors.append(MiseryIndex.MiseryFactor(
            type: .uv,
            value: Double(uvData.uvIndex),
            impact: getImpactLevel(score: uvScore, maxScore: 40),
            description: "UV Index: \(uvData.uvIndex)"
        ))
        totalScore += uvScore
        componentCount += 1
        
        // Temperature Factor (0-25 points)
        if let temperature = weatherViewModel.currentTemperature {
            let tempScore = calculateTemperatureMiseryScore(temperature: temperature)
            factors.append(MiseryIndex.MiseryFactor(
                type: .temperature,
                value: temperature,
                impact: getImpactLevel(score: tempScore, maxScore: 25),
                description: String(format: "Temperature: %.1f°C", temperature)
            ))
            totalScore += tempScore
            componentCount += 1
        }
        
        // Humidity Factor (0-20 points)
        if let humidity = weatherViewModel.currentHumidity {
            let humidityScore = calculateHumidityMiseryScore(humidity: humidity)
            factors.append(MiseryIndex.MiseryFactor(
                type: .humidity,
                value: humidity * 100,
                impact: getImpactLevel(score: humidityScore, maxScore: 20),
                description: String(format: "Humidity: %.0f%%", humidity * 100)
            ))
            totalScore += humidityScore
            componentCount += 1
        }
        
        // Wind Factor (0-15 points) - lack of wind increases misery
        if let windSpeed = weatherViewModel.currentWindSpeed {
            let windScore = calculateWindMiseryScore(windSpeed: windSpeed)
            factors.append(MiseryIndex.MiseryFactor(
                type: .wind,
                value: windSpeed,
                impact: getImpactLevel(score: windScore, maxScore: 15),
                description: String(format: "Wind: %.1f km/h", windSpeed)
            ))
            totalScore += windScore
            componentCount += 1
        }
        
        // Calculate final misery index (0-100)
        let maxPossibleScore = Double(componentCount * 25) // Normalized to 100
        let normalizedScore = min(100, (totalScore / maxPossibleScore) * 100)
        
        let level = getMiseryLevel(score: normalizedScore)
        let warning = generateMiseryWarning(score: normalizedScore, level: level)
        
        return MiseryIndex(
            value: normalizedScore,
            level: level,
            factors: factors,
            warning: warning
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCriticalUVHours(from hourlyData: [UVData]) -> (
        sunscreenHours: (start: Date, end: Date)?,
        shadeHours: (start: Date, end: Date)?,
        avoidSunHours: (start: Date, end: Date)?
    ) {
        let calendar = Calendar.current
        let today = Date()
        
        // Filter today's data
        let todayData = hourlyData.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        // Find continuous periods for each protection level
        let sunscreenPeriods = findContinuousPeriods(in: todayData, threshold: 3)
        let shadePeriods = findContinuousPeriods(in: todayData, threshold: 6)
        let avoidSunPeriods = findContinuousPeriods(in: todayData, threshold: 11)
        
        return (
            sunscreenHours: sunscreenPeriods.first,
            shadeHours: shadePeriods.first,
            avoidSunHours: avoidSunPeriods.first
        )
    }
    
    private func findContinuousPeriods(in data: [UVData], threshold: Int) -> [(start: Date, end: Date)] {
        var periods: [(start: Date, end: Date)] = []
        var currentStart: Date?
        
        for uvData in data.sorted(by: { $0.date < $1.date }) {
            if uvData.uvIndex >= threshold {
                if currentStart == nil {
                    currentStart = uvData.date
                }
            } else {
                if let start = currentStart {
                    periods.append((start: start, end: uvData.date))
                    currentStart = nil
                }
            }
        }
        
        // Handle case where period extends to end of data
        if let start = currentStart, let lastData = data.last {
            periods.append((start: start, end: lastData.date))
        }
        
        return periods
    }
    
    private func calculateUVMiseryScore(uvIndex: Int) -> Double {
        switch uvIndex {
        case 0...2: return 0
        case 3...5: return 8
        case 6...7: return 16
        case 8...10: return 25
        default: return 40 // 11+ (extreme levels including 12+)
        }
    }
    
    private func calculateTemperatureMiseryScore(temperature: Double) -> Double {
        switch temperature {
        case ..<10: return 5  // Cold is uncomfortable
        case 10..<20: return 0 // Comfortable
        case 20..<25: return 2 // Warm
        case 25..<30: return 8 // Hot
        case 30..<35: return 15 // Very hot
        case 35..<40: return 20 // Extremely hot
        default: return 25 // Dangerous
        }
    }
    
    private func calculateHumidityMiseryScore(humidity: Double) -> Double {
        let humidityPercent = humidity * 100
        switch humidityPercent {
        case 0..<30: return 5   // Too dry
        case 30..<60: return 0  // Comfortable
        case 60..<75: return 8  // Muggy
        case 75..<85: return 15 // Very humid
        default: return 20      // Oppressive
        }
    }
    
    private func calculateWindMiseryScore(windSpeed: Double) -> Double {
        switch windSpeed {
        case 0..<2: return 15   // No breeze, stifling
        case 2..<5: return 10   // Light breeze
        case 5..<10: return 5   // Gentle breeze, cooling
        case 10..<20: return 0  // Moderate breeze, comfortable
        case 20..<30: return 8  // Strong wind, annoying
        default: return 12      // Very strong wind
        }
    }
    
    private func getImpactLevel(score: Double, maxScore: Double) -> MiseryIndex.MiseryFactor.Impact {
        let percentage = (score / maxScore) * 100
        switch percentage {
        case 0..<15: return .minimal
        case 15..<30: return .low
        case 30..<50: return .moderate
        case 50..<70: return .high
        case 70..<85: return .severe
        default: return .extreme
        }
    }
    
    private func getMiseryLevel(score: Double) -> MiseryIndex.MiseryLevel {
        switch score {
        case 0..<15: return .pleasant
        case 15..<30: return .comfortable
        case 30..<45: return .noticeable
        case 45..<60: return .uncomfortable
        case 60..<75: return .oppressive
        case 75..<90: return .dangerous
        default: return .extreme
        }
    }
    
    private func generateOverallRecommendation(riskLevel: UVRiskLevel, miseryIndex: MiseryIndex) -> String {
        if miseryIndex.level == .extreme || miseryIndex.level == .dangerous {
            return "🚨 Extreme conditions - stay indoors with air conditioning"
        }
        
        switch riskLevel.level {
        case .low:
            return "☀️ Enjoy outdoor activities with basic protection"
        case .moderate:
            return "🧴 Apply sunscreen and stay hydrated"
        case .high:
            return "🌳 Limit outdoor time, seek shade frequently"
        case .veryHigh:
            return "⚠️ Minimize outdoor exposure, maximum protection required"
        case .extreme:
            return "🏠 Stay indoors - UV levels are hazardous"
        }
    }
    
    private func generateCriticalWarning(uvIndex: Int, miseryIndex: MiseryIndex) -> String? {
        if uvIndex >= 12 || miseryIndex.level == .extreme {
            return "⚠️ DANGER: Extreme conditions pose serious health risks"
        }
        
        if uvIndex >= 11 && miseryIndex.level == .dangerous {
            return "🚨 WARNING: Combined UV and weather conditions are hazardous"
        }
        
        return nil
    }
    
    private func generateMiseryWarning(score: Double, level: MiseryIndex.MiseryLevel) -> String? {
        switch level {
        case .dangerous:
            return "Heat-related illness risk is high"
        case .extreme:
            return "Life-threatening conditions - seek immediate shelter"
        default:
            return nil
        }
    }
}

// MARK: - Configuration

private struct RiskCalculationSettings {
    let sunscreenThreshold = 3
    let shadeThreshold = 6
    let avoidSunThreshold = 12 // UV 12+ represents extreme danger (sunburn in <5 min)
    let miseryCalculationInterval: TimeInterval = 300 // 5 minutes
}
