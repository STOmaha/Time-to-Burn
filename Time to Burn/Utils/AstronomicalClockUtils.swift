import SwiftUI

struct AstronomicalClockUtils {
    // Convert time to angle on the clock (0° = east/6am, 90° = south/noon, 180° = west/6pm, 270° = north/midnight)
    static func timeToAngle(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let totalSeconds = Double(hour * 3600 + minute * 60 + second)
        
        // Convert to angle: 6am = 0°, noon = 90°, 6pm = 180°, midnight = 270°
        let offsetSeconds = (totalSeconds - 6*3600 + 24*3600).truncatingRemainder(dividingBy: 24*3600)
        let angle = (offsetSeconds / (24*3600)) * 360
        
        print("🕐 TimeToAngle: \(hour):\(minute):\(second) -> \(angle)°")
        
        return angle
    }
    
    // Convert angle to position on a circle
    static func angleToPosition(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        // Portrait orientation: 0° (Noon) = top, 90° (6pm) = right, 180° (Midnight) = bottom, 270° (6am) = left
        // Apply 90° counterclockwise rotation
        let radians = (angle - 90) * .pi / 180
        let x = center.x + radius * sin(radians)
        let y = center.y - radius * cos(radians)
        
        print("📍 AngleToPosition: \(angle)° -> (\(x), \(y))")
        
        return CGPoint(x: x, y: y)
    }
    
    // Legacy function for backward compatibility (if needed)
    static func timeFraction(for date: Date) -> Double {
        return timeToAngle(for: date) / 360.0
    }
    
    // Legacy function for backward compatibility (if needed)
    static func positionOnPerimeter(t: Double, geo: GeometryProxy, verticalInset: CGFloat) -> CGPoint {
        let angle = t * 360
        return angleToPosition(
            angle: angle,
            center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
            radius: min(geo.size.width, geo.size.height) * 0.4
        )
    }
} 