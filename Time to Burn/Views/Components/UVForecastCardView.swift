import SwiftUI

struct UVForecastCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UV Index Forecast")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                        Text(locationManager.locationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                if let lastUpdated = weatherViewModel.lastUpdated {
                    Text("Updated \(UVColorUtils.formatHour(lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .center, spacing: 2) {
                    Text("\(weatherViewModel.currentUVData?.uvIndex ?? 0)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0))
                    Text(getUVLevelText(uv: weatherViewModel.currentUVData?.uvIndex ?? 0))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .foregroundColor(.primary)
                        Text("Time to Burn:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    Text("~\(getTimeToBurnString())")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            Text(getAdviceText(uv: weatherViewModel.currentUVData?.uvIndex ?? 0))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(20)
        .shadow(radius: 8)
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
    
    private func getAdviceText(uv: Int) -> String {
        switch uv {
        case 0...2:
            return "Low risk of harm. Enjoy your day!"
        case 3...5:
            return "Moderate risk of harm. Wear sunscreen, protective clothing, and seek shade during midday hours."
        case 6...7:
            return "High risk of harm. Reduce time in the sun between 11 AM and 3 PM."
        case 8...10:
            return "Very high risk of harm. Minimize sun exposure and use extra protection."
        default:
            return "Extreme risk of harm. Avoid sun exposure and stay indoors if possible."
        }
    }
    
    private func getTimeToBurnString() -> String {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        if uv == 0 { return "∞" }
        let minutes = UVData.calculateTimeToBurn(uvIndex: uv)
        return "\(minutes) minutes"
    }
} 