import SwiftUI
import CoreLocation

struct UVHomeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var homogeneousBackground: Color {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uv)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Subtle connection status indicator (only shows when not connected)
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
                
                UVForecastCardView()
                    .environmentObject(weatherViewModel)
                    .padding(.top, weatherViewModel.connectionStatus == .connected ? 24 : 8)
                
                // CloudCoverageCardView removed as requested
                
                UVChartCardView()
                    .environmentObject(weatherViewModel)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .refreshable {
            await weatherViewModel.refreshData()
        }
        .background(homogeneousBackground)
        .navigationTitle("UV Index")
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
            // NOTE: Weather refresh is now handled by WeatherViewModel directly with debouncing
            // The old weatherViewModel delegate pattern was removed to prevent cascade loops
            print("🏠 [UVHomeView] 📍 View appeared")
        }
        // Removed WeatherKit error alert - errors now handled gracefully without user interruption
    }
} 