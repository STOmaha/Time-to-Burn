import SwiftUI

struct WeatherDataCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 12) {
                    // Location and last updated
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(locationManager.locationName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            if let lastUpdated = weatherViewModel.lastUpdated {
                                Text("Updated \(UVColorUtils.formatHour(lastUpdated))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        Spacer()
                    }
                    
                    // Time to Burn
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time to Burn")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                            Text("~\(getTimeToBurnString())")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                }
                .padding(16)
            )
    }
    
    private func getTimeToBurnString() -> String {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        if uv == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurn(uvIndex: uv)
        return "\(minutes) minutes"
    }
} 