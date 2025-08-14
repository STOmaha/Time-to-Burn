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
                // Show search UI only when no city or celestial body is selected
                if searchViewModel.selectedLocation == nil && searchViewModel.selectedCelestialBody == nil {
                    // Concise Apple-like intro above search
                    SearchIntroHeader()
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    SearchBarView(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                        .background(Color.clear)
                        .zIndex(3)
                    
                    // Recent search history when idle (simple list on background)
                    if searchViewModel.searchText.isEmpty && searchViewModel.suggestions.isEmpty && searchViewModel.searchResults.isEmpty && !searchViewModel.searchHistory.isEmpty {
                        HistoryOverlay(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .zIndex(2)
                    }

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
                    if !searchViewModel.searchResults.isEmpty || !searchViewModel.celestialSearchResults.isEmpty {
                        SearchResultsOverlay(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                            .background(.regularMaterial) // was Color(.systemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .zIndex(2)
                    }
                }
                
                if searchViewModel.selectedLocation != nil || searchViewModel.selectedCelestialBody != nil {
                    SearchResultView(searchViewModel: searchViewModel) {
                        searchViewModel.clearSelection()
                        // Search bar will reappear; keep keyboard hidden until tapped
                        isSearchFocused = false
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    // No intro placeholder below when a city is not selected; we show only the search UI and results
                    EmptyView()
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
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .background(Color.clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.primary.opacity(0.25))
                }
                
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
                // Celestial bodies first (more fun!)
                ForEach(searchViewModel.celestialSearchResults) { celestialBody in
                    CelestialBodyRow(celestialBody: celestialBody) {
                        searchViewModel.selectCelestialBody(celestialBody)
                        isSearchFocused.wrappedValue = false
                    }
                    Divider()
                }
                
                // Regular location results
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

// MARK: - History Overlay
struct HistoryOverlay: View {
    @ObservedObject var searchViewModel: SearchViewModel
    var isSearchFocused: FocusState<Bool>.Binding
    
    var body: some View {
        // Plain list with thin separators, transparent background
        List {
            ForEach(searchViewModel.searchHistory) { result in
                SearchResultRow(result: result) {
                    searchViewModel.selectLocation(result)
                    isSearchFocused.wrappedValue = false
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.visible)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        searchViewModel.removeFromHistory(id: result.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                searchViewModel.removeFromHistory(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Concise Intro Header
struct SearchIntroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find a city")
                .font(.title2).fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Current UV and 7‑day forecast")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Celestial Body Row
struct CelestialBodyRow: View {
    let celestialBody: CelestialBody
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(celestialBody.emoji)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(celestialBody.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("UV \(celestialBody.uvIndex)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UVColorUtils.getUVColor(celestialBody.uvIndex))
                            .cornerRadius(4)
                    }
                    
                    Text(celestialBody.fullDisplayName)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
} 