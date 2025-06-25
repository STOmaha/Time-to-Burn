import SwiftUI

struct UVForecastCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UV Index Forecast")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(locationManager.locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let lastUpdated = weatherViewModel.lastUpdated {
                        Text("Updated \(UVColorUtils.formatHour(lastUpdated))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                // Main Content
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0).opacity(0.12))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 2) {
                            Text("\(weatherViewModel.currentUVData?.uvIndex ?? 0)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0))
                            Text(getUVLevelText(uv: weatherViewModel.currentUVData?.uvIndex ?? 0))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                                .foregroundColor(.primary)
                            Text("Time to Burn:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        Text("~\(getTimeToBurnString())")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                // Description
                Text(getAdviceText(uv: weatherViewModel.currentUVData?.uvIndex ?? 0))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
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
        return UVColorUtils.getUVAdvice(uvIndex: uv)
    }
    
    private func getTimeToBurnString() -> String {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        if uv == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurn(uvIndex: uv)
        return "\(minutes) minutes"
    }
} 