import SwiftUI
import WeatherKit

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if weatherViewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView("Loading UV data...")
                        .scaleEffect(1.5)
                    Text("Please ensure location services are enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = weatherViewModel.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error loading UV data")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            locationManager.requestLocation()
                            await weatherViewModel.refreshData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Location and UV Index Card
                        UVIndexCard(
                            location: locationManager.locationName,
                            uvData: weatherViewModel.currentUVData
                        )
                        
                        // Advice Card
                        if let uvData = weatherViewModel.currentUVData {
                            AdviceCard(advice: uvData.advice)
                        }
                        
                        // Time to Burn Card
                        if let uvData = weatherViewModel.currentUVData {
                            TimeToBurnCard(timeToBurn: uvData.timeToBurn)
                        }
                        
                        Button(action: {
                            Task {
                                locationManager.requestLocation()
                                await weatherViewModel.refreshData()
                            }
                        }) {
                            Label("Update Location", systemImage: "location.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                    .padding()
                }
            }
        }
        .task {
            print("ContentView: Initial task started")
            locationManager.requestLocation()
            if let location = locationManager.location {
                print("ContentView: Location available, fetching UV data")
                await weatherViewModel.fetchUVData(for: location)
            } else {
                print("ContentView: No location available")
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            print("ContentView: Location changed")
            if let location = newLocation {
                Task {
                    await weatherViewModel.fetchUVData(for: location)
                }
            }
        }
    }
}

struct UVIndexCard: View {
    let location: String
    let uvData: UVData?
    
    var body: some View {
        VStack(spacing: 15) {
            Text(location)
                .font(.title2)
                .fontWeight(.medium)
            
            if let uvData = uvData {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(uvData.uvIndex)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(uvIndexColor(uvData.uvIndex))
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func uvIndexColor(_ index: Int) -> Color {
        switch index {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
}

struct AdviceCard: View {
    let advice: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protection Advice")
                .font(.headline)
            
            Text(advice)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

struct TimeToBurnCard: View {
    let timeToBurn: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Time to Burn")
                .font(.headline)
            
            Text("\(timeToBurn) minutes")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.red)
            
            Text("of unprotected exposure")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(WeatherViewModel())
} 