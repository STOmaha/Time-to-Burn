import Foundation
import CoreLocation

struct MoonPositionCalculator {
    
    // MARK: - Moon Position Calculation
    /// Calculates the moon's position in the sky for a given location and time
    /// Returns azimuth (0-360 degrees, 0 = North, 90 = East, 180 = South, 270 = West)
    /// and altitude (0-90 degrees, 0 = horizon, 90 = zenith)
    static func calculateMoonPosition(for location: CLLocation, at date: Date) -> (azimuth: Double, altitude: Double) {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        
        print("🌙 MoonPositionCalculator: Calculating for date: \(date)")
        print("🌙 MoonPositionCalculator: Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Get Julian Day Number
        let jd = julianDay(for: date, timeZone: timeZone)
        print("🌙 MoonPositionCalculator: Julian Day: \(jd)")
        
        // Calculate moon's position
        let (moonAzimuth, moonAltitude) = calculateMoonAzimuthAltitude(
            julianDay: jd,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        print("🌙 MoonPositionCalculator: Final azimuth: \(moonAzimuth)°, altitude: \(moonAltitude)°")
        
        return (azimuth: moonAzimuth, altitude: moonAltitude)
    }
    
    /// Converts moon's sky position to a time fraction (0-1) for positioning on the clock
    /// 0 = East horizon (6am), 0.25 = South (noon), 0.5 = West horizon (6pm), 0.75 = North (midnight)
    static func moonPositionToTimeFraction(azimuth: Double, altitude: Double) -> Double {
        // If moon is below horizon (altitude < 0), we need to determine if it's rising or setting
        if altitude < 0 {
            // For below horizon, we need to estimate based on azimuth
            // This is a simplified approach - in reality, we'd need more complex calculations
            let normalizedAzimuth = (azimuth + 360).truncatingRemainder(dividingBy: 360)
            
            // Map azimuth to time fraction
            // East (90°) = 0 (6am), South (180°) = 0.25 (noon), West (270°) = 0.5 (6pm), North (0°/360°) = 0.75 (midnight)
            if normalizedAzimuth >= 45 && normalizedAzimuth < 135 {
                // East quadrant (rising)
                return 0.0 + (normalizedAzimuth - 45) / 90 * 0.25
            } else if normalizedAzimuth >= 135 && normalizedAzimuth < 225 {
                // South quadrant
                return 0.25 + (normalizedAzimuth - 135) / 90 * 0.25
            } else if normalizedAzimuth >= 225 && normalizedAzimuth < 315 {
                // West quadrant (setting)
                return 0.5 + (normalizedAzimuth - 225) / 90 * 0.25
            } else {
                // North quadrant
                let adjustedAzimuth = normalizedAzimuth < 45 ? normalizedAzimuth + 360 : normalizedAzimuth
                return 0.75 + (adjustedAzimuth - 315) / 90 * 0.25
            }
        } else {
            // Moon is above horizon - map directly based on azimuth
            let normalizedAzimuth = (azimuth + 360).truncatingRemainder(dividingBy: 360)
            
            // Map azimuth to time fraction with altitude consideration
            // Higher altitude means more centered, lower altitude means closer to horizon
            let altitudeFactor = 1.0 - (altitude / 90.0) * 0.1 // Small adjustment for altitude
            
            if normalizedAzimuth >= 45 && normalizedAzimuth < 135 {
                // East quadrant
                let baseFraction = 0.0 + (normalizedAzimuth - 45) / 90 * 0.25
                return baseFraction * altitudeFactor
            } else if normalizedAzimuth >= 135 && normalizedAzimuth < 225 {
                // South quadrant
                let baseFraction = 0.25 + (normalizedAzimuth - 135) / 90 * 0.25
                return baseFraction * altitudeFactor
            } else if normalizedAzimuth >= 225 && normalizedAzimuth < 315 {
                // West quadrant
                let baseFraction = 0.5 + (normalizedAzimuth - 225) / 90 * 0.25
                return baseFraction * altitudeFactor
            } else {
                // North quadrant
                let adjustedAzimuth = normalizedAzimuth < 45 ? normalizedAzimuth + 360 : normalizedAzimuth
                let baseFraction = 0.75 + (adjustedAzimuth - 315) / 90 * 0.25
                return baseFraction * altitudeFactor
            }
        }
    }
    
    // MARK: - Astronomical Calculations
    
    /// Calculate Julian Day Number
    private static func julianDay(for date: Date, timeZone: TimeZone) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second else {
            return 0.0
        }
        
        let y = month <= 2 ? year - 1 : year
        let m = month <= 2 ? month + 12 : month
        let d = Double(day) + Double(hour) / 24.0 + Double(minute) / 1440.0 + Double(second) / 86400.0
        
        // Break up the Julian Day calculation for compiler performance
        let a = floor(365.25 * Double(y + 4716))
        let b = floor(30.6001 * Double(m + 1))
        let jd = a + b + d - 1524.5
        
        // Adjust for timezone
        let timeZoneOffset = Double(timeZone.secondsFromGMT()) / 86400.0
        return jd - timeZoneOffset
    }
    
    /// Calculate moon's azimuth and altitude using simplified astronomical algorithms
    private static func calculateMoonAzimuthAltitude(julianDay: Double, latitude: Double, longitude: Double) -> (azimuth: Double, altitude: Double) {
        // Convert to radians
        let latRad = latitude * .pi / 180.0
        let lonRad = longitude * .pi / 180.0
        
        // Calculate moon's position using simplified algorithms
        // This is a basic implementation - for more accuracy, you'd use more complex algorithms
        
        // Calculate moon's ecliptic coordinates (simplified)
        let (moonRA, moonDec) = calculateMoonEclipticCoordinates(julianDay: julianDay)
        
        // Convert to horizontal coordinates
        let (azimuth, altitude) = equatorialToHorizontal(
            ra: moonRA,
            dec: moonDec,
            lat: latRad,
            lon: lonRad,
            jd: julianDay
        )
        
        return (azimuth: azimuth * 180.0 / .pi, altitude: altitude * 180.0 / .pi)
    }
    
    /// Calculate moon's ecliptic coordinates (simplified)
    private static func calculateMoonEclipticCoordinates(julianDay: Double) -> (ra: Double, dec: Double) {
        // Simplified moon position calculation
        // In a real implementation, you'd use more accurate astronomical algorithms
        
        let t = (julianDay - 2451545.0) / 36525.0
        
        // Moon's mean longitude (simplified)
        let L = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t + t * t * t / 538841.0 - t * t * t * t / 65194000.0
        
        // Moon's mean anomaly
        let M = 134.9623964 + 477198.8675055 * t + 0.0087414 * t * t + t * t * t / 69699.0 - t * t * t * t / 14712000.0
        
        // Moon's argument of latitude
        let F = 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t - t * t * t / 3526000.0 + t * t * t * t / 863310000.0
        
        // Convert to radians
        let LRad = (L * .pi / 180.0).truncatingRemainder(dividingBy: 2 * .pi)
        let _ = (M * .pi / 180.0).truncatingRemainder(dividingBy: 2 * .pi) // MRad not used in simplified calculation
        let FRad = (F * .pi / 180.0).truncatingRemainder(dividingBy: 2 * .pi)
        
        // Simplified conversion to equatorial coordinates
        let obliquity = 23.439 * .pi / 180.0 // Earth's axial tilt
        
        let ra = atan2(sin(LRad) * cos(obliquity) - tan(FRad) * sin(obliquity), cos(LRad))
        let dec = asin(sin(FRad) * cos(obliquity) + cos(FRad) * sin(obliquity) * sin(LRad))
        
        return (ra: ra, dec: dec)
    }
    
    /// Convert equatorial coordinates to horizontal coordinates
    private static func equatorialToHorizontal(ra: Double, dec: Double, lat: Double, lon: Double, jd: Double) -> (azimuth: Double, altitude: Double) {
        // Calculate local sidereal time
        let lst = calculateLocalSiderealTime(jd: jd, longitude: lon)
        
        // Hour angle
        let ha = lst - ra
        
        // Calculate altitude and azimuth
        let sinAlt = sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha)
        let altitude = asin(sinAlt)
        
        let cosAz = (sin(dec) - sin(altitude) * sin(lat)) / (cos(altitude) * cos(lat))
        let sinAz = -cos(dec) * sin(ha) / cos(altitude)
        let azimuth = atan2(sinAz, cosAz)
        
        return (azimuth: azimuth, altitude: altitude)
    }
    
    /// Calculate local sidereal time
    private static func calculateLocalSiderealTime(jd: Double, longitude: Double) -> Double {
        let t = (jd - 2451545.0) / 36525.0
        
        // Greenwich mean sidereal time
        let gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t - t * t * t / 38710000.0
        
        // Local sidereal time
        let lst = (gmst + longitude * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0)
        
        return lst * .pi / 180.0
    }
} 