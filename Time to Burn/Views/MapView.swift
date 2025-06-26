import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search location...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Search") {
                        // TODO: Implement location search
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                // Map placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .overlay(
                            VStack {
                                Image(systemName: "map.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Interactive map will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        )
                    
                    // Current location indicator
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // TODO: Center map on current location
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                    }
                }
                .padding()
                
                // Location info
                if let location = locationManager.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Location")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(locationManager.locationName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Lat: \(location.coordinate.latitude, specifier: "%.4f"), Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Update region to current location
            if let location = locationManager.location {
                region.center = location.coordinate
            }
        }
    }
} 