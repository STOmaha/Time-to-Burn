import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // MARK: - Homogeneous Background
    var homogeneousBackground: Color {
        let uvIndex = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Homogeneous UV background
                homogeneousBackground
                    .ignoresSafeArea()
                
                // Main Map View
                VStack(spacing: 0) {
                    // Search bar with autocomplete
                    SearchBarView(searchViewModel: searchViewModel)
                    
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
                
                // Search Results Overlay
                if !searchViewModel.searchResults.isEmpty && searchViewModel.selectedLocation == nil {
                    SearchResultsOverlay(searchViewModel: searchViewModel)
                }
                
                // Search Result View (Full Screen)
                if searchViewModel.selectedLocation != nil {
                    SearchResultView(searchViewModel: searchViewModel) {
                        searchViewModel.clearSelection()
                    }
                    .transition(.move(edge: .trailing))
                }
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

// MARK: - Search Bar View

struct SearchBarView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search cities, areas...", text: $searchViewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchViewModel.searchText.isEmpty {
                        Button(action: {
                            searchViewModel.searchText = ""
                            searchViewModel.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if isSearchFocused {
                    Button("Cancel") {
                        isSearchFocused = false
                        searchViewModel.searchText = ""
                        searchViewModel.searchResults = []
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Search indicator
            if searchViewModel.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Search Results Overlay

struct SearchResultsOverlay: View {
    @ObservedObject var searchViewModel: SearchViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Results list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchViewModel.searchResults) { result in
                        SearchResultRow(result: result) {
                            searchViewModel.selectLocation(result)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
            
            Spacer()
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    searchViewModel.searchResults = []
                }
        )
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: LocationSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(result.fullDisplayName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        
        // Note: Divider will be handled by the parent view
    }
} 