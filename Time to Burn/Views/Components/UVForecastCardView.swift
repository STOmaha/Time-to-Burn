import SwiftUI

struct UVForecastCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        let uvColor = UVColorUtils.getUVColor(uv)
        let advice = UVColorUtils.getUVAdvice(uvIndex: uv)
        let level = UVColorUtils.getUVCategory(for: uv)
        let timeToBurn = getTimeToBurnString()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UV Index Forecast")
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(locationManager.locationName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                if let lastUpdated = weatherViewModel.lastUpdated {
                    Text("Updated \(UVColorUtils.formatHour(lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text("\(uv)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor.opacity(0.85))
                    Text(level)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(uvColor.opacity(0.85))
                }
                .offset(x: 20)
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .foregroundColor(.primary)
                        Text("Time to Burn:")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("~\(timeToBurn)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            Text(advice)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
    }
    
    private func getTimeToBurnString() -> String {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        if uv == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurnMinutes(uvIndex: uv)
        return "\(minutes) minutes"
    }
}

// MARK: - Color Extension for Darker/Complementary Color
extension Color {
    func darker(by amount: CGFloat = 0.2) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return Color(hue: hue, saturation: saturation, brightness: max(brightness - amount, 0), opacity: Double(alpha))
        }
        return self
    }
} 