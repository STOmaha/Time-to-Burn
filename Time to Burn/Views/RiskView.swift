import SwiftUI

struct RiskView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var riskViewModel = UVRiskViewModel()
    
    var homogeneousBackground: Color {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uv)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connection status indicator
                if weatherViewModel.connectionStatus != .connected {
                    HStack {
                        Image(systemName: weatherViewModel.connectionStatus == .reconnecting ? "arrow.clockwise" : "wifi.slash")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(weatherViewModel.connectionStatus.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
                
                // Single Comprehensive Risk Assessment Card
                if let riskAssessment = riskViewModel.currentRiskAssessment {
                    comprehensiveRiskCard(riskAssessment: riskAssessment)
                        .padding(.top, weatherViewModel.connectionStatus == .connected ? 24 : 8)
                } else if riskViewModel.isCalculating {
                    // Loading state
                    loadingCard
                        .padding(.top, weatherViewModel.connectionStatus == .connected ? 24 : 8)
                } else {
                    // No data state
                    noDataCard
                        .padding(.top, weatherViewModel.connectionStatus == .connected ? 24 : 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .refreshable {
            await weatherViewModel.refreshData()
        }
        .background(homogeneousBackground)
        .navigationTitle("UV Risk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await weatherViewModel.refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            // Configure risk assessment system
            riskViewModel.configure(with: weatherViewModel)
        }
    }
    
    // MARK: - Single Comprehensive Risk Card
    
    private func comprehensiveRiskCard(riskAssessment: UVRiskDisplayModel) -> some View {
        let uvColor = UVColorUtils.getUVColor(riskAssessment.uvIndex)
        let uvCategory = UVColorUtils.getUVCategory(for: riskAssessment.uvIndex)
        let timeToBurn = getTimeToBurnString(for: riskAssessment.uvIndex)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header Section
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UV Risk Assessment")
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
            
            // Main UV Display Section
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text("\(riskAssessment.uvIndex)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor.opacity(0.85))
                    Text(uvCategory)
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
            
            // Risk Level Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(riskAssessment.riskLevel.emoji)
                        .font(.title2)
                    Text("Risk Level: \(riskAssessment.riskLevel.level.rawValue)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(riskAssessment.riskLevel.color)
                }
                
                Text(riskAssessment.riskLevel.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Divider
            Divider()
                .foregroundColor(uvColor.opacity(0.3))
                .padding(.vertical, 4)
            
            // Sun Protection Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                        .font(.headline)
                        .foregroundColor(uvColor.opacity(0.8))
                    Text("Sun Protection")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                SunProtectionTimesView(protectionGuidance: riskAssessment.protectionGuidance)
            }
            
            // Divider
            Divider()
                .foregroundColor(uvColor.opacity(0.3))
                .padding(.vertical, 4)
            
            // Comfort Index Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "thermometer.sun.fill")
                        .font(.headline)
                        .foregroundColor(riskAssessment.miseryIndex.level.color)
                    Text("Comfort Index")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                MiseryIndexView(miseryIndex: riskAssessment.miseryIndex)
            }
            
            // Critical Warning Section (if present)
            if let criticalWarning = riskAssessment.criticalWarning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Warning")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    Text(criticalWarning)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.red.opacity(0.1))
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
    }
    
    private func getTimeToBurnString(for uvIndex: Int) -> String {
        if uvIndex == 0 { return "∞" }
        let minutes = UVColorUtils.calculateTimeToBurnMinutes(uvIndex: uvIndex)
        return "\(minutes) minutes"
    }
    
    // MARK: - Optional: Individual card functions removed
    // All risk components are now consolidated in comprehensiveRiskCard
    
    // MARK: - Loading Card
    
    private var loadingCard: some View {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        let uvColor = UVColorUtils.getUVColor(uv)
        
        return VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(uvColor)
            
            Text("Calculating Risk Assessment...")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Analyzing UV conditions and weather factors")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
    }
    
    // MARK: - No Data Card
    
    private var noDataCard: some View {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        let uvColor = UVColorUtils.getUVColor(uv)
        
        return VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(uvColor.opacity(0.8))
            
            Text("No Risk Data Available")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Risk assessment will be available when weather data is loaded. Pull down to refresh.")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
    }
}

// MARK: - Preview

struct RiskView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RiskView()
                .environmentObject(LocationManager.shared)
                .environmentObject(WeatherViewModel(locationManager: LocationManager.shared))
        }
    }
}
