import SwiftUI

struct UVForecastCardView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var locationManager: LocationManager
    
    // State for managing minimum refreshing display time
    @State private var isShowingRefreshing = false
    @State private var refreshingStartTime: Date?
    @State private var pendingHideTask: Task<Void, Never>?

    private let minimumRefreshingDuration: TimeInterval = 1.5 // 1.5 seconds minimum
    private let debounceDelay: TimeInterval = 0.3 // Debounce to prevent flashing
    
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
                if isShowingRefreshing {
                    Text("Refreshing")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.7))
                } else if let lastUpdated = weatherViewModel.lastUpdated {
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
        .onChange(of: weatherViewModel.isLoading) { _, newValue in
            handleLoadingStateChange(isLoading: newValue)
        }
    }
    
    private func getTimeToBurnString() -> String {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        if uv == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurnMinutes(uvIndex: uv)
        return "\(minutes) minutes"
    }
    
    private func handleLoadingStateChange(isLoading: Bool) {
        if isLoading {
            // Cancel any pending hide task - loading started again
            pendingHideTask?.cancel()
            pendingHideTask = nil

            // Start showing refreshing immediately (only set start time if not already refreshing)
            if !isShowingRefreshing {
                refreshingStartTime = Date()
            }
            isShowingRefreshing = true
        } else {
            // Debounce the hide - wait briefly to see if loading starts again
            pendingHideTask?.cancel()
            pendingHideTask = Task {
                // Wait for debounce delay first
                try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))

                // Check if cancelled (loading started again)
                if Task.isCancelled { return }

                // Check if minimum time has passed
                guard let startTime = refreshingStartTime else {
                    await MainActor.run {
                        isShowingRefreshing = false
                    }
                    return
                }

                let elapsedTime = Date().timeIntervalSince(startTime)
                let totalMinimumTime = minimumRefreshingDuration

                if elapsedTime >= totalMinimumTime {
                    // Enough time has passed, stop showing refreshing
                    await MainActor.run {
                        isShowingRefreshing = false
                        refreshingStartTime = nil
                    }
                } else {
                    // Not enough time has passed, wait for the remaining duration
                    let remainingTime = totalMinimumTime - elapsedTime
                    try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))

                    // Check if cancelled again
                    if Task.isCancelled { return }

                    await MainActor.run {
                        isShowingRefreshing = false
                        refreshingStartTime = nil
                    }
                }
            }
        }
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