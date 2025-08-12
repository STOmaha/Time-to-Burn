import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    
    // MARK: - Homogeneous Background
    var homogeneousBackground: Color {
        let uvIndex = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Homogeneous UV background
            homogeneousBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search bar with autocomplete
                SearchBarView(searchViewModel: searchViewModel)
                    .background(Color(.systemBackground))
                    .zIndex(2)
                
                // Content area
                if let _ = searchViewModel.selectedLocation {
                    // Show search result detail (scrollable)
                    SearchResultView(searchViewModel: searchViewModel) {
                        searchViewModel.clearSelection()
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    // Empty guidance view matching app style
                    ScrollView {
                        VStack(spacing: 16) {
                            Spacer(minLength: 24)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Search for a city or area")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Get current UV and a 7-day forecast for any place")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                    .background(Color.clear)
                }
            }
            .zIndex(1)
            
            // Search Results Overlay anchored under the search bar
            if !searchViewModel.searchResults.isEmpty && searchViewModel.selectedLocation == nil {
                VStack(spacing: 0) {
                    // Spacer to push results below the search bar height
                    Spacer().frame(height: 64) // approximate bar + padding
                    SearchResultsOverlay(searchViewModel: searchViewModel)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    Spacer()
                }
                .allowsHitTesting(true)
                .zIndex(3)
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
        // Results list only; no dim background so it won't cover the text field
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchViewModel.searchResults) { result in
                    SearchResultRow(result: result) {
                        searchViewModel.selectLocation(result)
                    }
                    Divider()
                }
            }
        }
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
    }
} 