import Foundation
import CoreLocation
import WeatherKit

@MainActor
class EnvironmentalDataService: ObservableObject {
    static let shared = EnvironmentalDataService()
    
    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager
    
    @Published var currentEnvironmentalFactors: EnvironmentalFactors?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    
    private init() {
        self.locationManager = LocationManager.shared
    }
    
    // MARK: - Main Data Fetching
    
    /// Fetch comprehensive environmental data for a location
    func fetchEnvironmentalData(for location: CLLocation) async -> EnvironmentalFactors? {
        print("🌍 [EnvironmentalDataService] Fetching environmental data...")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // Fetch all environmental data concurrently
            async let altitude = fetchAltitude(for: location)
            async let snowConditions = fetchSnowConditions(for: location)
            async let waterProximity = fetchWaterProximity(for: location)
            async let seasonalFactors = calculateSeasonalFactors()
            
            // Wait for all data to be fetched
            let (alt, snow, water, seasonal) = await (altitude, snowConditions, waterProximity, seasonalFactors)
            
            // Analyze terrain type
            let terrainType = TerrainAnalysisUtils.analyzeTerrainType(
                location: location,
                altitude: alt,
                waterProximity: water
            )
            
            // Create environmental factors
            let environmentalFactors = EnvironmentalFactors(
                location: location.coordinate,
                altitude: alt,
                snowConditions: snow,
                waterProximity: water,
                terrainType: terrainType,
                seasonalFactors: seasonal
            )
            
            await MainActor.run {
                self.currentEnvironmentalFactors = environmentalFactors
                self.lastUpdated = Date()
                self.isLoading = false
                
                print("🌍 [EnvironmentalDataService] ✅ Environmental data loaded successfully!")
                print("   📍 Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                let altitudeText = alt.isFinite ? "\(Int(alt))m" : "Unknown"
                let snowCoverageText = snow.snowCoverage.isFinite ? "\(Int(snow.snowCoverage))% coverage" : "Unknown coverage"
                print("   ⛰️ Altitude: \(altitudeText)")
                print("   ❄️ Snow: \(snow.snowType.rawValue) (\(snowCoverageText))")
                let distanceText = water.distanceToWater.isFinite ? "\(Int(water.distanceToWater))m away" : "No water nearby"
                print("   💧 Water: \(water.waterBodyType.rawValue) (\(distanceText))")
                print("   🏔️ Terrain: \(terrainType.rawValue)")
                print("   🍂 Season: \(seasonal.season.rawValue)")
                print("   ──────────────────────────────────────")
            }
            
            return environmentalFactors
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                
                print("🌍 [EnvironmentalDataService] ❌ Error fetching environmental data: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    /// Refresh environmental data for current location
    func refreshEnvironmentalData() async {
        guard let location = locationManager.location else {
            print("🌍 [EnvironmentalDataService] ❌ No location available")
            return
        }
        
        _ = await fetchEnvironmentalData(for: location)
    }
    
    // MARK: - Individual Data Fetching Methods
    
    /// Fetch altitude data for a location
    private func fetchAltitude(for location: CLLocation) async -> Double {
        return await AltitudeUtils.fetchAltitude(for: location)
    }
    
    /// Fetch snow conditions for a location
    private func fetchSnowConditions(for location: CLLocation) async -> SnowConditions {
        do {
            let weather = try await weatherService.weather(for: location, including: .current)
            return await SnowReflectionUtils.fetchSnowConditions(from: weather)
        } catch {
            print("🌍 [EnvironmentalDataService] ⚠️ Error fetching snow conditions: \(error.localizedDescription)")
            return SnowConditions() // Return default (no snow)
        }
    }
    
    /// Fetch water proximity data for a location
    private func fetchWaterProximity(for location: CLLocation) async -> WaterProximity {
        return await WaterReflectionUtils.fetchWaterProximity(for: location)
    }
    
    /// Calculate seasonal factors
    private func calculateSeasonalFactors() async -> SeasonalFactors {
        let calendar = Calendar.current
        let now = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        
        // Determine season based on date
        let season = determineSeason(for: now)
        
        // Check for special days
        let isWinterSolstice = isWinterSolstice(date: now)
        let isSummerSolstice = isSummerSolstice(date: now)
        let isEquinox = isEquinox(date: now)
        
        // Calculate seasonal UV multiplier
        let seasonalUVMultiplier = calculateSeasonalUVMultiplier(
            season: season,
            dayOfYear: dayOfYear,
            isWinterSolstice: isWinterSolstice,
            isSummerSolstice: isSummerSolstice,
            isEquinox: isEquinox
        )
        
        return SeasonalFactors(
            season: season,
            dayOfYear: dayOfYear,
            isWinterSolstice: isWinterSolstice,
            isSummerSolstice: isSummerSolstice,
            isEquinox: isEquinox,
            seasonalUVMultiplier: seasonalUVMultiplier
        )
    }
    
    // MARK: - Seasonal Calculations
    
    /// Determine season based on date
    private func determineSeason(for date: Date) -> SeasonalFactors.Season {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        switch month {
        case 12, 1, 2:
            return .winter
        case 3, 4, 5:
            return .spring
        case 6, 7, 8:
            return .summer
        case 9, 10, 11:
            return .autumn
        default:
            return .unknown
        }
    }
    
    /// Check if date is winter solstice
    private func isWinterSolstice(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Winter solstice is around December 21-22
        return month == 12 && (day == 21 || day == 22)
    }
    
    /// Check if date is summer solstice
    private func isSummerSolstice(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Summer solstice is around June 20-21
        return month == 6 && (day == 20 || day == 21)
    }
    
    /// Check if date is equinox
    private func isEquinox(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Spring equinox is around March 20-21
        // Fall equinox is around September 22-23
        return (month == 3 && (day == 20 || day == 21)) ||
               (month == 9 && (day == 22 || day == 23))
    }
    
    /// Calculate seasonal UV multiplier
    private func calculateSeasonalUVMultiplier(
        season: SeasonalFactors.Season,
        dayOfYear: Int,
        isWinterSolstice: Bool,
        isSummerSolstice: Bool,
        isEquinox: Bool
    ) -> Double {
        var multiplier = season.uvMultiplier
        
        // Adjust for solstices and equinoxes
        if isWinterSolstice {
            multiplier *= 0.8 // Even lower UV during winter solstice
        } else if isSummerSolstice {
            multiplier *= 1.1 // Even higher UV during summer solstice
        } else if isEquinox {
            multiplier *= 0.9 // Moderate UV during equinoxes
        }
        
        // Adjust based on day of year (smooth transition)
        let dayAdjustment = calculateDayOfYearAdjustment(dayOfYear: dayOfYear)
        multiplier *= dayAdjustment
        
        return multiplier
    }
    
    /// Calculate day of year adjustment for smooth seasonal transitions
    private func calculateDayOfYearAdjustment(dayOfYear: Int) -> Double {
        // Create a smooth sine wave adjustment based on day of year
        let angle = (Double(dayOfYear) / 365.0) * 2.0 * .pi
        let adjustment = sin(angle) * 0.1 + 1.0 // ±10% adjustment
        
        return adjustment
    }
    
    // MARK: - Data Validation
    
    /// Validate environmental data
    func validateEnvironmentalData(_ factors: EnvironmentalFactors) -> Bool {
        // Check for reasonable altitude values
        guard factors.altitude >= -500 && factors.altitude <= 9000 else {
            print("🌍 [EnvironmentalDataService] ❌ Invalid altitude: \(factors.altitude)")
            return false
        }
        
        // Check for reasonable snow coverage
        guard factors.snowConditions.snowCoverage >= 0 && factors.snowConditions.snowCoverage <= 100 else {
            print("🌍 [EnvironmentalDataService] ❌ Invalid snow coverage: \(factors.snowConditions.snowCoverage)")
            return false
        }
        
        // Check for reasonable water distance
        guard factors.waterProximity.distanceToWater >= 0 else {
            print("🌍 [EnvironmentalDataService] ❌ Invalid water distance: \(factors.waterProximity.distanceToWater)")
            return false
        }
        
        return true
    }
    
    // MARK: - Data Caching
    
    /// Cache environmental data
    func cacheEnvironmentalData(_ factors: EnvironmentalFactors) {
        let userDefaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(factors) {
            userDefaults.set(encoded, forKey: "cachedEnvironmentalFactors")
            userDefaults.set(Date(), forKey: "environmentalDataCacheDate")
            print("🌍 [EnvironmentalDataService] 💾 Cached environmental data")
        }
    }
    
    /// Load cached environmental data
    func loadCachedEnvironmentalData() -> EnvironmentalFactors? {
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: "cachedEnvironmentalFactors"),
              let factors = try? JSONDecoder().decode(EnvironmentalFactors.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid (less than 1 hour old)
        if let cacheDate = userDefaults.object(forKey: "environmentalDataCacheDate") as? Date {
            let timeSinceCache = Date().timeIntervalSince(cacheDate)
            if timeSinceCache < 3600 { // 1 hour
                print("🌍 [EnvironmentalDataService] 📦 Loaded cached environmental data")
                return factors
            }
        }
        
        return nil
    }
    
    /// Clear cached environmental data
    func clearCachedEnvironmentalData() {
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "cachedEnvironmentalFactors")
        userDefaults.removeObject(forKey: "environmentalDataCacheDate")
        print("🌍 [EnvironmentalDataService] 🗑️ Cleared cached environmental data")
    }
    
    // MARK: - Error Handling
    
    /// Handle environmental data errors
    private func handleError(_ error: Error, context: String) {
        print("🌍 [EnvironmentalDataService] ❌ Error in \(context): \(error.localizedDescription)")
        
        // Log error details for debugging
        if let nsError = error as NSError? {
            print("   🔍 Domain: \(nsError.domain)")
            print("   🔢 Code: \(nsError.code)")
            print("   📝 Description: \(nsError.localizedDescription)")
        }
    }
} 