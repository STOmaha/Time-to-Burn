import SwiftUI
import CoreLocation

struct AstronomicalClockView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    // Configuration for positioning adjustments
    private let verticalInset: CGFloat = 24 // Adjust this value to move elements inward from the border
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                let now = timeline.date
                let sunT = timeFraction(for: now)
                
                // Calculate moon position based on real astronomical data
                let moonT = calculateMoonTimeFraction(for: now, location: locationManager.location)
                
                let sunPos = positionOnPerimeter(t: sunT, geo: geo)
                let moonPos = positionOnPerimeter(t: moonT, geo: geo)
                
                // Debug logging
                // debugLog(sunT: sunT, moonT: moonT, sunPos: sunPos, moonPos: moonPos)
                
                ZStack(alignment: .top) {
                    // Large rounded rectangle border, nearly touching the black border
                    RoundedRectangle(cornerRadius: min(geo.size.width, geo.size.height) * 0.18)
                        .stroke(Color.white.opacity(0.7), lineWidth: 4)
                        .frame(
                            width: geo.size.width * 0.98,
                            height: geo.size.height * 0.98
                        )
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    
                    // Time labels
                    TimeLabelsView(
                        rectWidth: geo.size.width * 0.98,
                        rectHeight: geo.size.height * 0.98,
                        geo: geo,
                        verticalInset: verticalInset
                    )
                    
                    // Sun and Moon
                    SunMoonView(sunPos: sunPos, moonPos: moonPos)
                        .zIndex(2)
                    
                    // Astronomical markers (sunrise/sunset from WeatherKit)
                    AstronomicalMarkersView(weatherViewModel: weatherViewModel, geo: geo, verticalInset: verticalInset)
                        .zIndex(2)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear {
                    print("🌍 AstronomicalClock: View appeared")
                    print("🌍 AstronomicalClock: Location available: \(locationManager.location != nil)")
                    if let location = locationManager.location {
                        print("🌍 AstronomicalClock: Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    }
                    print("☀️ Sun: timeFraction=\(sunT), position=\(sunPos)")
                    print("🌙 Moon: timeFraction=\(moonT), position=\(moonPos)")
                    print("🌅 WeatherKit sunrise: \(weatherViewModel.sunriseTime?.description ?? "nil")")
                    print("🌇 WeatherKit sunset: \(weatherViewModel.sunsetTime?.description ?? "nil")")
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Functions
    private func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        // 6am (East) = 0, noon (South) = 0.25, 6pm (West) = 0.5, midnight (North) = 0.75
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        let result = offsetSeconds / (24*3600)
        print("☀️ Sun calculation: \(hour):\(minute):\(second) -> timeFraction=\(result)")
        return result
    }
    
    private func calculateMoonTimeFraction(for date: Date, location: CLLocation?) -> Double {
        print("🌙 Moon calculation started for date: \(date)")
        
        guard let location = location else {
            print("🌙 Moon: No location available, using fallback calculation")
            // Fallback to simple offset if no location available
            let sunT = timeFraction(for: date)
            let fallbackT = (sunT + 0.5).truncatingRemainder(dividingBy: 1.0)
            print("🌙 Moon: Fallback time fraction: \(fallbackT)")
            return fallbackT
        }
        
        print("🌙 Moon: Calculating position for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Calculate moon's real position in the sky
        let (azimuth, altitude) = MoonPositionCalculator.calculateMoonPosition(for: location, at: date)
        
        print("🌙 Moon: Calculated azimuth: \(azimuth)°, altitude: \(altitude)°")
        
        // Convert to time fraction for positioning on the clock
        let timeFraction = MoonPositionCalculator.moonPositionToTimeFraction(azimuth: azimuth, altitude: altitude)
        
        print("🌙 Moon: Final time fraction: \(timeFraction)")
        
        return timeFraction
    }
    
    private func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
        let rectWidth = geo.size.width * 0.92
        let rectHeight = geo.size.height * 0.92
        let cornerRadius = min(rectWidth, rectHeight) * 0.18
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2
        let halfWidth = rectWidth / 2 - verticalInset // Apply inset to move elements inward
        let halfHeight = rectHeight / 2 - verticalInset // Apply inset to move elements inward
        
        // Calculate the perimeter length to map time to position
        let straightLength = 2 * (rectWidth + rectHeight - 2 * cornerRadius)
        let cornerLength = 2 * .pi * cornerRadius
        let totalPerimeter = straightLength + cornerLength
        
        // Map time (0-1) to distance along perimeter
        // 6am (East) = 0, noon (South) = 0.25, 6pm (West) = 0.5, midnight (North) = 0.75
        let distance = t * totalPerimeter
        
        // Determine which segment we're on and calculate position
        var currentDistance = 0.0
        
        // Right edge (6am position - East horizon, bottom to top)
        let rightEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + rightEdgeLength {
            let progress = (distance - currentDistance) / rightEdgeLength
            let x = centerX + halfWidth
            let y = centerY + halfHeight - cornerRadius - progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += rightEdgeLength
        
        // Top-right corner
        let cornerArcLength = .pi * cornerRadius / 2
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * cos(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Top edge (noon position - South, right to left)
        let topEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + topEdgeLength {
            let progress = (distance - currentDistance) / topEdgeLength
            let x = centerX + halfWidth - cornerRadius - progress * (rectWidth - 2 * cornerRadius)
            let y = centerY - halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += topEdgeLength
        
        // Top-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * sin(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Left edge (6pm position - West horizon, top to bottom)
        let leftEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + leftEdgeLength {
            let progress = (distance - currentDistance) / leftEdgeLength
            let x = centerX - halfWidth
            let y = centerY - halfHeight + cornerRadius + progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += leftEdgeLength
        
        // Bottom-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * cos(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Bottom edge (midnight position - North, left to right)
        let bottomEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + bottomEdgeLength {
            let progress = (distance - currentDistance) / bottomEdgeLength
            let x = centerX - halfWidth + cornerRadius + progress * (rectWidth - 2 * cornerRadius)
            let y = centerY + halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += bottomEdgeLength
        
        // Bottom-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * sin(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        
        // Fallback to right edge (6am position - East horizon)
        return CGPoint(x: centerX + halfWidth, y: centerY)
    }
    
    // MARK: - Debug Functions
    // private func debugLog(sunT: Double, moonT: Double, sunPos: CGPoint, moonPos: CGPoint) {
    //     print("🌍 AstronomicalClock: Location available: \(locationManager.location != nil)")
    //     if let location = locationManager.location {
    //         print("🌍 AstronomicalClock: Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    //     } else {
    //         print("🌍 AstronomicalClock: No location available")
    //     }
    //     print("☀️ Sun: timeFraction=\(sunT), position=\(sunPos)")
    //     print("🌙 Moon: timeFraction=\(moonT), position=\(moonPos)")
    // }
}

// MARK: - Supporting Views
struct TimeLabelsView: View {
    let rectWidth: CGFloat
    let rectHeight: CGFloat
    let geo: GeometryProxy
    let verticalInset: CGFloat
    
    var body: some View {
        Group {
            Text("6am")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2 + rectWidth / 2 - verticalInset, y: geo.size.height / 2)
            
            Text("Noon")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - rectHeight / 2 + verticalInset)
            
            Text("6pm")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2 - rectWidth / 2 + verticalInset, y: geo.size.height / 2)
            
            Text("Midnight")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2, y: geo.size.height / 2 + rectHeight / 2 - verticalInset)
        }
    }
}

struct SunMoonView: View {
    let sunPos: CGPoint
    let moonPos: CGPoint
    
    var body: some View {
        Group {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
                .position(sunPos)
                .shadow(radius: 10)
                .animation(.easeInOut(duration: 0.8), value: sunPos)
            
            Image(systemName: "moon.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue.opacity(0.8))
                .position(moonPos)
                .shadow(radius: 8)
                .animation(.easeInOut(duration: 0.8), value: moonPos)
        }
    }
}

struct AstronomicalMarkersView: View {
    let weatherViewModel: WeatherViewModel
    let geo: GeometryProxy
    let verticalInset: CGFloat
    
    var body: some View {
        Group {
            // Sunrise marker
            if let sunrise = weatherViewModel.sunriseTime {
                let sunriseT = timeFraction(for: sunrise)
                let sunrisePos = positionOnPerimeter(t: sunriseT, geo: geo)
                VStack(spacing: 2) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                        .shadow(radius: 4)
                    Text(sunrise, style: .time)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .position(sunrisePos)
                .onAppear {
                    print("🌅 Sunrise marker displayed at: \(sunrise), position: \(sunrisePos)")
                }
            }
            
            // Sunset marker
            if let sunset = weatherViewModel.sunsetTime {
                let sunsetT = timeFraction(for: sunset)
                let sunsetPos = positionOnPerimeter(t: sunsetT, geo: geo)
                VStack(spacing: 2) {
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.pink)
                        .shadow(radius: 4)
                    Text(sunset, style: .time)
                        .font(.caption)
                        .foregroundColor(.pink)
                }
                .position(sunsetPos)
                .onAppear {
                    print("🌇 Sunset marker displayed at: \(sunset), position: \(sunsetPos)")
                }
            }
        }
        .onAppear {
            print("🌅🌇 AstronomicalMarkersView appeared")
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
    
    private func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        // 6am (East) = 0, noon (South) = 0.25, 6pm (West) = 0.5, midnight (North) = 0.75
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        return offsetSeconds / (24*3600)
    }
    
    private func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
        let rectWidth = geo.size.width * 0.92
        let rectHeight = geo.size.height * 0.92
        let cornerRadius = min(rectWidth, rectHeight) * 0.18
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2
        let halfWidth = rectWidth / 2 - verticalInset // Apply inset to move elements inward
        let halfHeight = rectHeight / 2 - verticalInset // Apply inset to move elements inward
        
        let straightLength = 2 * (rectWidth + rectHeight - 2 * cornerRadius)
        let cornerLength = 2 * .pi * cornerRadius
        let totalPerimeter = straightLength + cornerLength
        let distance = t * totalPerimeter
        
        var currentDistance = 0.0
        
        // Right edge (6am position - East horizon, bottom to top)
        let rightEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + rightEdgeLength {
            let progress = (distance - currentDistance) / rightEdgeLength
            let x = centerX + halfWidth
            let y = centerY + halfHeight - cornerRadius - progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += rightEdgeLength
        
        // Top-right corner
        let cornerArcLength = .pi * cornerRadius / 2
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * cos(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Top edge (noon position - South, right to left)
        let topEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + topEdgeLength {
            let progress = (distance - currentDistance) / topEdgeLength
            let x = centerX + halfWidth - cornerRadius - progress * (rectWidth - 2 * cornerRadius)
            let y = centerY - halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += topEdgeLength
        
        // Top-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * sin(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Left edge (6pm position - West horizon, top to bottom)
        let leftEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + leftEdgeLength {
            let progress = (distance - currentDistance) / leftEdgeLength
            let x = centerX - halfWidth
            let y = centerY - halfHeight + cornerRadius + progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += leftEdgeLength
        
        // Bottom-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * cos(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Bottom edge (midnight position - North, left to right)
        let bottomEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + bottomEdgeLength {
            let progress = (distance - currentDistance) / bottomEdgeLength
            let x = centerX - halfWidth + cornerRadius + progress * (rectWidth - 2 * cornerRadius)
            let y = centerY + halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += bottomEdgeLength
        
        // Bottom-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * sin(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        
        // Fallback to right edge (6am position - East horizon)
        return CGPoint(x: centerX + halfWidth, y: centerY)
    }
} 