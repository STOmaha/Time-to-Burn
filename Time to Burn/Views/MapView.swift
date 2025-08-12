import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Homogeneous Background
    var homogeneousBackground: Color {
        let selectedUV = searchViewModel.selectedLocationUVData?.uvIndex
        let currentUV = weatherViewModel.currentUVData?.uvIndex
        let uvIndex = selectedUV ?? currentUV ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            homogeneousBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Show search UI only when no city is selected
                if searchViewModel.selectedLocation == nil {
                    SearchBarView(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                        .background(.ultraThinMaterial) // was Color(.systemBackground)
                        .zIndex(3)
                    
                    // Suggestions directly under the bar (for 1–2 letters)
                    if !searchViewModel.suggestions.isEmpty {
                        SuggestionsOverlay(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                            .background(.regularMaterial) // was Color(.systemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .zIndex(2)
                    }
                    
                    // Full search results (3+ letters)
                    if !searchViewModel.searchResults.isEmpty {
                        SearchResultsOverlay(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                            .background(.regularMaterial) // was Color(.systemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .zIndex(2)
                    }
                }
                
                if let _ = searchViewModel.selectedLocation {
                    SearchResultView(searchViewModel: searchViewModel) {
                        searchViewModel.clearSelection()
                        // Search bar will reappear; keep keyboard hidden until tapped
                        isSearchFocused = false
                    }
                    .transition(.move(edge: .trailing))
                } else {
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
                        .padding(.top, 24)
                    }
                    .background(Color.clear)
                }
            }
        }
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    var isSearchFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search cities, areas...", text: $searchViewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused(isSearchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchViewModel.searchText.isEmpty {
                        Button(action: {
                            searchViewModel.searchText = ""
                            searchViewModel.suggestions = []
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
                
                if isSearchFocused.wrappedValue {
                    Button("Cancel") {
                        isSearchFocused.wrappedValue = false
                        searchViewModel.searchText = ""
                        searchViewModel.suggestions = []
                        searchViewModel.searchResults = []
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if searchViewModel.isSearching {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(.clear) // was Color(.systemBackground)
    }
}

// MARK: - Suggestions Overlay
struct SuggestionsOverlay: View {
    @ObservedObject var searchViewModel: SearchViewModel
    var isSearchFocused: FocusState<Bool>.Binding
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchViewModel.suggestions, id: \.self) { s in
                    Button(action: {
                        searchViewModel.selectSuggestion(s)
                        isSearchFocused.wrappedValue = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if !s.subtitle.isEmpty {
                                    Text(s.subtitle)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
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
                    Divider()
                }
            }
        }
    }
}

// MARK: - Search Results Overlay
struct SearchResultsOverlay: View {
    @ObservedObject var searchViewModel: SearchViewModel
    var isSearchFocused: FocusState<Bool>.Binding
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchViewModel.searchResults) { result in
                    SearchResultRow(result: result) {
                        searchViewModel.selectLocation(result)
                        isSearchFocused.wrappedValue = false
                    }
                    Divider()
                }
            }
        }
    }
}

// MARK: - Search Result Row (unchanged)
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