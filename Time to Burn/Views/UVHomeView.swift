import SwiftUI
import CoreLocation

struct UVHomeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var pastelBackground: Color {
        let uv = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getPastelUVColor(uv)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                UVForecastCardView()
                    .environmentObject(weatherViewModel)
                    .padding(.top, 24)
                UVChartCardView()
                    .environmentObject(weatherViewModel)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .refreshable {
            await weatherViewModel.refreshData()
        }
        .background(pastelBackground)
        .navigationTitle("UV Index")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.weatherViewModel = weatherViewModel
            print("🏠 [UVHomeView] 📍 Connected to location manager")
        }
        .alert("WeatherKit Error", isPresented: $weatherViewModel.showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(weatherViewModel.errorMessage)
        }
    }
} 