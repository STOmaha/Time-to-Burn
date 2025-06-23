import Foundation

struct SunExposureCalculator {
    /// Calculates the estimated minutes to burn for a given UV index,
    /// assuming an average fair skin type (Fitzpatrick Type II).
    /// Base minutes to burn at a UV Index of 1 for Type II skin is 100.
    static func minutesToBurn(uvIndex: Double) -> Double {
        guard uvIndex > 0 else { return .infinity }
        let baseMinutes = 100.0 // Corresponds to Skin Type II
        return baseMinutes / uvIndex
    }
} 