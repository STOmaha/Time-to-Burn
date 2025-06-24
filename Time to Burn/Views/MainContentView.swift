import SwiftUI
import CoreLocation

struct MainContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var astronomicalClockViewModel = AstronomicalClockViewModel()
    @State private var showingNotifications = false
    @State private var showingUVChart = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background color based on current UV value
                UVColorUtils.getUVColor(weatherViewModel.currentUVData?.uvIndex ?? 0)
                    .ignoresSafeArea()
                
                // Main content inside rounded rectangle and perimeter track
                VStack(spacing: 0) {
                    Spacer(minLength: 8)
                    ZStack {
                        // Rounded rectangle border and perimeter track
                        AstronomicalClockView()
                            .environmentObject(weatherViewModel)
                            .environmentObject(astronomicalClockViewModel)
                            .allowsHitTesting(false)
                        
                        // Scrollable content inside the rounded rectangle
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                // Forecast Card
                                UVForecastCardView()
                                    .environmentObject(weatherViewModel)
                                    .environmentObject(locationManager)
                                    .environmentObject(notificationService)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                // Chart Card
                                UVChartView()
                                    .environmentObject(weatherViewModel)
                                    .environmentObject(notificationService)
                                    .padding(.bottom, 16)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    Spacer(minLength: 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Image(systemName: "bell")
                    }
                }
            }
        }
        .onAppear {
            locationManager.weatherViewModel = weatherViewModel
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