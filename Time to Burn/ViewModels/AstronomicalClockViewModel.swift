import Foundation
import SwiftUI

@MainActor
class AstronomicalClockViewModel: ObservableObject {
    @Published var currentTime = Date()
    @Published var sunPosition: CGPoint = .zero
    @Published var moonPosition: CGPoint = .zero
    
    private var timer: Timer?
    
    init() {
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Time Calculations
    func timeFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        // 6am = 0, noon = 0.25, 6pm = 0.5, midnight = 0.75
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        return offsetSeconds / (24*3600)
    }
    
    func getSunTimeFraction() -> Double {
        return timeFraction(for: currentTime)
    }
    
    func getMoonTimeFraction() -> Double {
        let sunT = getSunTimeFraction()
        return (sunT + 0.5).truncatingRemainder(dividingBy: 1.0)
    }
    
    // MARK: - Position Calculations
    func positionOnPerimeter(t: Double, geo: GeometryProxy) -> CGPoint {
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