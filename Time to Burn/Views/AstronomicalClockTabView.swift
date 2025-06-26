import SwiftUI
import CoreLocation

struct AstronomicalClockTabView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Tasteful dark background
                Color(red: 0.1, green: 0.1, blue: 0.15)
                    .ignoresSafeArea()
                
                // Astronomical clock
                AstronomicalClockView()
                    .frame(width: geo.size.width * 0.96, height: geo.size.height * 0.96)
                    .zIndex(2)
                
                // Weather data card below the clock
                VStack {
                    Spacer()
                    WeatherDataCardView()
                        .environmentObject(weatherViewModel)
                        .environmentObject(locationManager)
                        .frame(width: geo.size.width * 0.9)
                        .padding(.bottom, 20)
                }
                .zIndex(3)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Astronomical Clock")
        .navigationBarTitleDisplayMode(.inline)
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