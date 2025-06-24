import SwiftUI

struct AstronomicalClockView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                let now = timeline.date
                let sunT = timeFraction(for: now)
                let moonT = (sunT + 0.5).truncatingRemainder(dividingBy: 1.0)
                let sunPos = positionOnPerimeter(t: sunT, geo: geo)
                let moonPos = positionOnPerimeter(t: moonT, geo: geo)
                
                ZStack(alignment: .top) {
                    // Rounded rectangle border
                    RoundedRectangle(cornerRadius: min(geo.size.width, geo.size.height) * 0.18)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(
                            width: geo.size.width * 0.96,
                            height: geo.size.height * 0.96,
                            alignment: .top
                        )
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.48 + 8)
                    
                    // Time labels
                    TimeLabelsView(
                        rectWidth: geo.size.width * 0.96,
                        rectHeight: geo.size.height * 0.96,
                        geo: geo
                    )
                    
                    // Sun and Moon
                    SunMoonView(sunPos: sunPos, moonPos: moonPos)
                    
                    // Astronomical markers
                    AstronomicalMarkersView(weatherViewModel: weatherViewModel, geo: geo)
                    
                    // Loading indicator
                    if weatherViewModel.sunrise == nil && weatherViewModel.sunset == nil && 
                       weatherViewModel.moonrise == nil && weatherViewModel.moonset == nil {
                        AstronomicalLoadingIndicatorView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Helper Functions
    private func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        // 6am = 0, noon = 0.25, 6pm = 0.5, midnight = 0.75
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        return offsetSeconds / (24*3600)
    }
    
    private func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
        let rectWidth = geo.size.width * 0.92
        let rectHeight = geo.size.height * 0.92
        let cornerRadius = min(rectWidth, rectHeight) * 0.18
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2
        let halfWidth = rectWidth / 2
        let halfHeight = rectHeight / 2
        
        // Calculate the perimeter length to map time to position
        let straightLength = 2 * (rectWidth + rectHeight - 2 * cornerRadius)
        let cornerLength = 2 * .pi * cornerRadius
        let totalPerimeter = straightLength + cornerLength
        
        // Map time (0-1) to distance along perimeter
        // 6am = 0, noon = 0.25, 6pm = 0.5, midnight = 0.75
        let distance = t * totalPerimeter
        
        // Determine which segment we're on and calculate position
        var currentDistance = 0.0
        
        // Left edge (6am position - bottom to top)
        let leftEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + leftEdgeLength {
            let progress = (distance - currentDistance) / leftEdgeLength
            let x = centerX - halfWidth
            let y = centerY + halfHeight - cornerRadius - progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += leftEdgeLength
        
        // Top-left corner
        let cornerArcLength = .pi * cornerRadius / 2
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * sin(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Top edge (noon position - left to right)
        let topEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + topEdgeLength {
            let progress = (distance - currentDistance) / topEdgeLength
            let x = centerX - halfWidth + cornerRadius + progress * (rectWidth - 2 * cornerRadius)
            let y = centerY - halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += topEdgeLength
        
        // Top-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * cos(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Right edge (6pm position - top to bottom)
        let rightEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + rightEdgeLength {
            let progress = (distance - currentDistance) / rightEdgeLength
            let x = centerX + halfWidth
            let y = centerY - halfHeight + cornerRadius + progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += rightEdgeLength
        
        // Bottom-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * sin(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Bottom edge (midnight position - right to left)
        let bottomEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + bottomEdgeLength {
            let progress = (distance - currentDistance) / bottomEdgeLength
            let x = centerX + halfWidth - cornerRadius - progress * (rectWidth - 2 * cornerRadius)
            let y = centerY + halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += bottomEdgeLength
        
        // Bottom-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * cos(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        
        // Fallback to left edge (6am position)
        return CGPoint(x: centerX - halfWidth, y: centerY)
    }
}

// MARK: - Supporting Views
struct TimeLabelsView: View {
    let rectWidth: CGFloat
    let rectHeight: CGFloat
    let geo: GeometryProxy
    
    var body: some View {
        Group {
            Text("6am")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2 - rectWidth / 2, y: geo.size.height / 2)
            
            Text("Noon")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - rectHeight / 2)
            
            Text("6pm")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2 + rectWidth / 2, y: geo.size.height / 2)
            
            Text("Midnight")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .position(x: geo.size.width / 2, y: geo.size.height / 2 + rectHeight / 2)
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
    
    var body: some View {
        Group {
            // Sunrise marker
            if let sunrise = weatherViewModel.sunrise {
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
            }
            
            // Sunset marker
            if let sunset = weatherViewModel.sunset {
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
            }
            
            // Moonrise marker
            if let moonrise = weatherViewModel.moonrise {
                let moonriseT = timeFraction(for: moonrise)
                let moonrisePos = positionOnPerimeter(t: moonriseT, geo: geo)
                VStack(spacing: 2) {
                    Image(systemName: "moonrise.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                        .shadow(radius: 4)
                    Text(moonrise, style: .time)
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
                .position(moonrisePos)
            }
            
            // Moonset marker
            if let moonset = weatherViewModel.moonset {
                let moonsetT = timeFraction(for: moonset)
                let moonsetPos = positionOnPerimeter(t: moonsetT, geo: geo)
                VStack(spacing: 2) {
                    Image(systemName: "moonset.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.indigo)
                        .shadow(radius: 4)
                    Text(moonset, style: .time)
                        .font(.caption2)
                        .foregroundColor(.indigo)
                }
                .position(moonsetPos)
            }
        }
    }
    
    private func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        return offsetSeconds / (24*3600)
    }
    
    private func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
        let rectWidth = geo.size.width * 0.92
        let rectHeight = geo.size.height * 0.92
        let cornerRadius = min(rectWidth, rectHeight) * 0.18
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2
        let halfWidth = rectWidth / 2
        let halfHeight = rectHeight / 2
        
        let straightLength = 2 * (rectWidth + rectHeight - 2 * cornerRadius)
        let cornerLength = 2 * .pi * cornerRadius
        let totalPerimeter = straightLength + cornerLength
        let distance = t * totalPerimeter
        
        var currentDistance = 0.0
        
        // Left edge
        let leftEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + leftEdgeLength {
            let progress = (distance - currentDistance) / leftEdgeLength
            let x = centerX - halfWidth
            let y = centerY + halfHeight - cornerRadius - progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += leftEdgeLength
        
        // Top-left corner
        let cornerArcLength = .pi * cornerRadius / 2
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * sin(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Top edge
        let topEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + topEdgeLength {
            let progress = (distance - currentDistance) / topEdgeLength
            let x = centerX - halfWidth + cornerRadius + progress * (rectWidth - 2 * cornerRadius)
            let y = centerY - halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += topEdgeLength
        
        // Top-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * cos(angle)
            let y = centerY - halfHeight + cornerRadius - cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Right edge
        let rightEdgeLength = rectHeight - 2 * cornerRadius
        if distance <= currentDistance + rightEdgeLength {
            let progress = (distance - currentDistance) / rightEdgeLength
            let x = centerX + halfWidth
            let y = centerY - halfHeight + cornerRadius + progress * (rectHeight - 2 * cornerRadius)
            return CGPoint(x: x, y: y)
        }
        currentDistance += rightEdgeLength
        
        // Bottom-right corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX + halfWidth - cornerRadius + cornerRadius * sin(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * cos(angle)
            return CGPoint(x: x, y: y)
        }
        currentDistance += cornerArcLength
        
        // Bottom edge
        let bottomEdgeLength = rectWidth - 2 * cornerRadius
        if distance <= currentDistance + bottomEdgeLength {
            let progress = (distance - currentDistance) / bottomEdgeLength
            let x = centerX + halfWidth - cornerRadius - progress * (rectWidth - 2 * cornerRadius)
            let y = centerY + halfHeight
            return CGPoint(x: x, y: y)
        }
        currentDistance += bottomEdgeLength
        
        // Bottom-left corner
        if distance <= currentDistance + cornerArcLength {
            let progress = (distance - currentDistance) / cornerArcLength
            let angle = progress * .pi / 2
            let x = centerX - halfWidth + cornerRadius - cornerRadius * cos(angle)
            let y = centerY + halfHeight - cornerRadius + cornerRadius * sin(angle)
            return CGPoint(x: x, y: y)
        }
        
        return CGPoint(x: centerX - halfWidth, y: centerY)
    }
}

struct AstronomicalLoadingIndicatorView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .foregroundColor(.white)
            Text("Loading astronomical data...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 8)
        }
    }
} 