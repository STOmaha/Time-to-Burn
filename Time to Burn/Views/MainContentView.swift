import SwiftUI
import CoreLocation

struct MainContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark background color for astronomical theme
                Color.black
                    .ignoresSafeArea()
                
                // Astronomical perimeter (Sun, Moon, Rectangle, Markers)
                AstronomicalClockView()
                    .frame(width: geo.size.width * 0.96, height: geo.size.height * 0.96)
                    .zIndex(2)
                
                // Interior content (UV Data and Chart)
                VStack(spacing: 20) {
                    Spacer(minLength: geo.size.height * 0.18)
                    UVForecastCardView()
                        .environmentObject(weatherViewModel)
                        .padding(.horizontal, geo.size.width * 0.08)
                    UVChartView()
                        .environmentObject(weatherViewModel)
                        .padding(.horizontal, geo.size.width * 0.08)
                    Spacer(minLength: geo.size.height * 0.12)
                }
                .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.92)
                .zIndex(3)
            }
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationSettingsView()) {
                    Image(systemName: "bell")
                }
            }
        }
        .onAppear {
            locationManager.weatherViewModel = weatherViewModel
            
            // Fetch weather data when view appears
            Task {
                await weatherViewModel.refreshData()
            }
        }
        .alert("WeatherKit Error", isPresented: $weatherViewModel.showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(weatherViewModel.errorMessage)
        }
    }
}

// MARK: - Supporting Views

struct ErrorDisplayView: View {
    let errorMessage: String?
    let retryAction: () -> Void
    
    var body: some View {
        if let errorMessage = errorMessage {
            VStack {
                Text("⚠️ Weather Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: retryAction)
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct WeatherLoadingIndicatorView: View {
    let isLoading: Bool
    
    var body: some View {
        if isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading weather data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct LocationInfoView: View {
    let locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📍 Location")
                .font(.headline)
                .fontWeight(.medium)
            Text(locationManager.locationName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let location = locationManager.location {
                Text("Lat: \(location.coordinate.latitude, specifier: "%.4f"), Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
} 