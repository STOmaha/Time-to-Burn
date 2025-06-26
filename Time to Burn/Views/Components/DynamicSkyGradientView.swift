import SwiftUI

struct DynamicSkyGradientView: View {
    let sunriseTime: Date?
    let sunsetTime: Date?
    
    private var gradient: LinearGradient {
        let stops = calculateGradientStops()
        
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        Rectangle()
            .fill(gradient)
            .ignoresSafeArea()
    }
    
    private func calculateGradientStops() -> [Gradient.Stop] {
        guard let sunrise = sunriseTime, let sunset = sunsetTime else {
            // Default gradient if no sunrise/sunset data
            return [
                Gradient.Stop(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0),
                Gradient.Stop(color: Color.black, location: 1.0)
            ]
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Convert times to fractions of the day (0.0 = start of day, 1.0 = end of day)
        let sunriseFraction = sunrise.timeIntervalSince(startOfDay) / endOfDay.timeIntervalSince(startOfDay)
        let sunsetFraction = sunset.timeIntervalSince(startOfDay) / endOfDay.timeIntervalSince(startOfDay)
        
        // Clamp fractions to valid range
        let clampedSunrise = max(0.0, min(1.0, sunriseFraction))
        let clampedSunset = max(0.0, min(1.0, sunsetFraction))
        
        // Create gradient stops
        var stops: [Gradient.Stop] = []
        
        // Sky blue at top
        stops.append(Gradient.Stop(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0))
        
        // Transition to sunrise colors
        if clampedSunrise > 0.1 {
            stops.append(Gradient.Stop(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: clampedSunrise - 0.1))
        }
        
        // Sunrise colors (orange)
        stops.append(Gradient.Stop(color: Color(red: 1.0, green: 0.6, blue: 0.4), location: clampedSunrise))
        
        // Sunset colors (red) - direct transition from orange to red
        stops.append(Gradient.Stop(color: Color(red: 1.0, green: 0.2, blue: 0.2), location: clampedSunset))
        
        // Transition to night
        if clampedSunset < 0.9 {
            stops.append(Gradient.Stop(color: Color(red: 0.2, green: 0.1, blue: 0.3), location: clampedSunset + 0.1))
        }
        
        // Black at bottom
        stops.append(Gradient.Stop(color: Color.black, location: 1.0))
        
        return stops
    }
    
    private func calculateGradientColors() -> [Color] {
        // This method is not used in the current implementation
        // but kept for potential future use
        return [
            Color(red: 0.53, green: 0.81, blue: 0.98), // Sky blue
            Color(red: 1.0, green: 0.6, blue: 0.4),   // Sunrise orange
            Color(red: 1.0, green: 0.4, blue: 0.6),   // Sunset pink
            Color.black
        ]
    }
}

#Preview {
    DynamicSkyGradientView(
        sunriseTime: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()),
        sunsetTime: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())
    )
} 