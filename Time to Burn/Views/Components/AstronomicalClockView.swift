import SwiftUI
import CoreLocation

struct AstronomicalClockView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    // Configuration for circular clock
    private let clockRadius: CGFloat = 0.4 // Relative to screen size
    private let markerRadius: CGFloat = 0.45 // Slightly larger for time markers
    
    var body: some View {
        GeometryReader { geo in
            let now = Date()
            let sunAngle = AstronomicalClockUtils.timeToAngle(for: now)
            let moonAngle = calculateMoonAngle(for: now, location: locationManager.location)
            
            ZStack {
                // Circular clock background
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: geo.size.width * clockRadius * 2, height: geo.size.height * clockRadius * 2)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Time markers (6am, noon, 6pm, midnight)
                TimeMarkersView(geo: geo, markerRadius: markerRadius)
                
                // Sun
                let sunPosition = AstronomicalClockUtils.angleToPosition(
                    angle: sunAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * clockRadius
                )
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)
                    .position(sunPosition)
                    .shadow(radius: 10)
                
                // Moon
                let moonPosition = AstronomicalClockUtils.angleToPosition(
                    angle: moonAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * clockRadius
                )
                
                let (moonIcon, moonColor) = getMoonAppearance()
                
                Image(systemName: moonIcon)
                    .font(.system(size: 44))
                    .foregroundColor(moonColor)
                    .position(moonPosition)
                    .shadow(radius: 8)
                
                // Sunrise and Sunset markers
                SunriseSunsetMarkersView(
                    weatherViewModel: weatherViewModel,
                    geo: geo,
                    clockRadius: clockRadius
                )
                
                // UV Index in center
                UVIndexCenterView(
                    weatherViewModel: weatherViewModel,
                    geo: geo,
                    clockRadius: clockRadius
                )
                
                // Moonrise and Moonset markers
                MoonriseMoonsetMarkersView(
                    weatherViewModel: weatherViewModel,
                    geo: geo,
                    clockRadius: clockRadius
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                print("🌍 AstronomicalClock: View appeared")
                print("☀️ Sun: angle=\(sunAngle)°")
                print("🌙 Moon: angle=\(moonAngle)°")
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Functions
    private func calculateMoonAngle(for date: Date, location: CLLocation?) -> Double {
        guard let location = location else {
            // Fallback to simple offset if no location available
            let sunAngle = AstronomicalClockUtils.timeToAngle(for: date)
            let fallbackAngle = (sunAngle + 180).truncatingRemainder(dividingBy: 360)
            return fallbackAngle
        }
        
        // Calculate moon's real position in the sky
        let (azimuth, _) = MoonPositionCalculator.calculateMoonPosition(for: location, at: date)
        
        // Convert azimuth to clock angle (0° = east, 90° = south, 180° = west, 270° = north)
        let clockAngle = MoonPositionCalculator.azimuthToClockAngle(azimuth: azimuth)
        
        return clockAngle
    }
    
    private func getMoonAppearance() -> (String, Color) {
        guard let moonset = weatherViewModel.moonsetTime else {
            return ("moon.fill", .blue.opacity(0.8))
        }
        
        let now = Date()
        let timeUntilMoonset = moonset.timeIntervalSince(now)
        
        // If within 2 hours of moonset, show setting moon
        if timeUntilMoonset > 0 && timeUntilMoonset < 7200 { // 2 hours = 7200 seconds
            return ("moon.zzz.fill", .orange.opacity(0.9))
        }
        
        // If within 2 hours after moonset, show hidden moon
        if timeUntilMoonset < 0 && timeUntilMoonset > -7200 {
            return ("moon.fill", .gray.opacity(0.5))
        }
        
        return ("moon.fill", .blue.opacity(0.8))
    }
}

// MARK: - Supporting Views
struct TimeMarkersView: View {
    let geo: GeometryProxy
    let markerRadius: CGFloat
    
    var body: some View {
        Group {
            // 6am (East) - Right
            TimeMarker(
                text: "6am",
                angle: 0,
                geo: geo,
                radius: markerRadius
            )
            
            // Noon (South) - Bottom
            TimeMarker(
                text: "Noon",
                angle: 90,
                geo: geo,
                radius: markerRadius
            )
            
            // 6pm (West) - Left
            TimeMarker(
                text: "6pm",
                angle: 180,
                geo: geo,
                radius: markerRadius
            )
            
            // Midnight (North) - Top
            TimeMarker(
                text: "Midnight",
                angle: 270,
                geo: geo,
                radius: markerRadius
            )
        }
    }
}

struct TimeMarker: View {
    let text: String
    let angle: Double
    let geo: GeometryProxy
    let radius: CGFloat
    
    var body: some View {
        let position = AstronomicalClockUtils.angleToPosition(
            angle: angle,
            center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
            radius: geo.size.width * radius
        )
        
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .position(position)
    }
}

struct SunriseSunsetMarkersView: View {
    let weatherViewModel: WeatherViewModel
    let geo: GeometryProxy
    let clockRadius: CGFloat
    
    var body: some View {
        Group {
            // Sunrise marker
            if let sunrise = weatherViewModel.sunriseTime {
                let sunriseAngle = AstronomicalClockUtils.timeToAngle(for: sunrise)
                let sunrisePosition = AstronomicalClockUtils.angleToPosition(
                    angle: sunriseAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * (clockRadius + 0.05) // Slightly outside the main circle
                )
                
                VStack(spacing: 2) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                        .shadow(radius: 4)
                    Text(sunrise, style: .time)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .position(sunrisePosition)
                .onAppear {
                    print("🌅 Sunrise marker displayed at: \(sunrise), angle: \(sunriseAngle)°")
                }
            }
            
            // Sunset marker
            if let sunset = weatherViewModel.sunsetTime {
                let sunsetAngle = AstronomicalClockUtils.timeToAngle(for: sunset)
                let sunsetPosition = AstronomicalClockUtils.angleToPosition(
                    angle: sunsetAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * (clockRadius + 0.05) // Slightly outside the main circle
                )
                
                VStack(spacing: 2) {
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.pink)
                        .shadow(radius: 4)
                    Text(sunset, style: .time)
                        .font(.caption)
                        .foregroundColor(.pink)
                }
                .position(sunsetPosition)
                .onAppear {
                    print("🌇 Sunset marker displayed at: \(sunset), angle: \(sunsetAngle)°")
                }
            }
        }
        .onAppear {
            print("🌅🌇 SunriseSunsetMarkersView appeared")
            print("🌅🌇 WeatherKit sunrise: \(weatherViewModel.sunriseTime?.description ?? "nil")")
            print("🌇 WeatherKit sunset: \(weatherViewModel.sunsetTime?.description ?? "nil")")
            
            if weatherViewModel.sunriseTime == nil {
                print("🌅 No sunrise data available from WeatherKit")
            }
            if weatherViewModel.sunsetTime == nil {
                print("🌇 No sunset data available from WeatherKit")
            }
        }
    }
}

struct UVIndexCenterView: View {
    let weatherViewModel: WeatherViewModel
    let geo: GeometryProxy
    let clockRadius: CGFloat
    
    var body: some View {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        let uvColor = UVColorUtils.getUVColor(uv)
        
        ZStack {
            // Background circle with UV color
            Circle()
                .fill(uvColor.opacity(0.9))
                .frame(width: geo.size.width * clockRadius * 0.8, height: geo.size.height * clockRadius * 0.8)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .shadow(radius: 8)
            
            // UV Index content
            VStack(spacing: 4) {
                Text("\(uv)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                Text(getUVLevelText(uv: uv))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
    
    private func getUVLevelText(uv: Int) -> String {
        switch uv {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
}

struct MoonriseMoonsetMarkersView: View {
    let weatherViewModel: WeatherViewModel
    let geo: GeometryProxy
    let clockRadius: CGFloat
    
    var body: some View {
        Group {
            // Moonrise marker
            if let moonrise = weatherViewModel.moonriseTime {
                let moonriseAngle = AstronomicalClockUtils.timeToAngle(for: moonrise)
                let moonrisePosition = AstronomicalClockUtils.angleToPosition(
                    angle: moonriseAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * (clockRadius + 0.08)
                )
                VStack(spacing: 2) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.purple)
                        .shadow(radius: 4)
                    Text(moonrise, style: .time)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .position(moonrisePosition)
                .onAppear {
                    print("🌙 Moonrise marker displayed at: \(moonrise), angle: \(moonriseAngle)°")
                }
            }
            // Moonset marker
            if let moonset = weatherViewModel.moonsetTime {
                let moonsetAngle = AstronomicalClockUtils.timeToAngle(for: moonset)
                let moonsetPosition = AstronomicalClockUtils.angleToPosition(
                    angle: moonsetAngle,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    radius: geo.size.width * (clockRadius + 0.08)
                )
                VStack(spacing: 2) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                        .shadow(radius: 4)
                    Text(moonset, style: .time)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .position(moonsetPosition)
                .onAppear {
                    print("🌙 Moonset marker displayed at: \(moonset), angle: \(moonsetAngle)°")
                }
            }
        }
    }
}

// MARK: - Mask Shapes
struct SkyMask: Shape, @unchecked Sendable {
    let sunriseTime: Date?
    let sunsetTime: Date?
    let geo: GeometryProxy
    let verticalInset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard let sunrise = sunriseTime, let sunset = sunsetTime else {
            // If no sunrise/sunset data, show full sky
            path.addRect(rect)
            return path
        }
        
        let sunrisePos = AstronomicalClockUtils.positionOnPerimeter(t: AstronomicalClockUtils.timeFraction(for: sunrise), geo: geo, verticalInset: verticalInset)
        let sunsetPos = AstronomicalClockUtils.positionOnPerimeter(t: AstronomicalClockUtils.timeFraction(for: sunset), geo: geo, verticalInset: verticalInset)
        
        // Create a path that covers the area above the horizon line
        // Start from the very top of the screen
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        // Create the horizon curve
        let horizonPath = Path { horizonPath in
            horizonPath.move(to: sunrisePos)
            
            let midPoint = CGPoint(
                x: (sunrisePos.x + sunsetPos.x) / 2,
                y: (sunrisePos.y + sunsetPos.y) / 2
            )
            
            let controlPoint1 = CGPoint(
                x: sunrisePos.x + (midPoint.x - sunrisePos.x) * 0.5,
                y: sunrisePos.y
            )
            
            let controlPoint2 = CGPoint(
                x: sunsetPos.x - (sunsetPos.x - midPoint.x) * 0.5,
                y: sunsetPos.y
            )
            
            horizonPath.addCurve(to: sunsetPos, control1: controlPoint1, control2: controlPoint2)
            
            // Complete the path to the bottom
            horizonPath.addLine(to: CGPoint(x: rect.width, y: rect.height))
            horizonPath.addLine(to: CGPoint(x: 0, y: rect.height))
            horizonPath.closeSubpath()
        }
        
        // Subtract the ground area from the sky
        path = path.subtracting(horizonPath)
        
        return path
    }
}

struct GroundMask: Shape, @unchecked Sendable {
    let sunriseTime: Date?
    let sunsetTime: Date?
    let geo: GeometryProxy
    let verticalInset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard let sunrise = sunriseTime, let sunset = sunsetTime else {
            // If no sunrise/sunset data, show full ground
            path.addRect(rect)
            return path
        }
        
        let sunrisePos = AstronomicalClockUtils.positionOnPerimeter(t: AstronomicalClockUtils.timeFraction(for: sunrise), geo: geo, verticalInset: verticalInset)
        let sunsetPos = AstronomicalClockUtils.positionOnPerimeter(t: AstronomicalClockUtils.timeFraction(for: sunset), geo: geo, verticalInset: verticalInset)
        
        // Create the horizon curve that defines the ground area
        path.move(to: sunrisePos)
        
        let midPoint = CGPoint(
            x: (sunrisePos.x + sunsetPos.x) / 2,
            y: (sunrisePos.y + sunsetPos.y) / 2
        )
        
        let controlPoint1 = CGPoint(
            x: sunrisePos.x + (midPoint.x - sunrisePos.x) * 0.5,
            y: sunrisePos.y
        )
        
        let controlPoint2 = CGPoint(
            x: sunsetPos.x - (sunsetPos.x - midPoint.x) * 0.5,
            y: sunsetPos.y
        )
        
        path.addCurve(to: sunsetPos, control1: controlPoint1, control2: controlPoint2)
        
        // Complete the path to the bottom
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// Linear interpolation for Color
extension Color {
    static func lerp(from: Color, to: Color, t: CGFloat) -> Color {
        let fromComponents = from.components()
        let toComponents = to.components()
        let r = fromComponents.r + (toComponents.r - fromComponents.r) * t
        let g = fromComponents.g + (toComponents.g - fromComponents.g) * t
        let b = fromComponents.b + (toComponents.b - fromComponents.b) * t
        let a = fromComponents.a + (toComponents.a - fromComponents.a) * t
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    // Extract RGBA components
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return (0, 0, 0, 1)
        #endif
    }
} 