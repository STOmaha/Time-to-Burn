import Foundation
import CoreLocation
import WeatherKit
import Combine
import MapKit
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [LocationSearchResult] = []
    @Published var selectedLocation: LocationSearchResult?
    @Published var selectedLocationUVData: UVData?
    @Published var selectedLocationHourlyUVData: [UVData] = []
    @Published var selectedLocationDailyUVData: [[UVData]] = [] // 7-day hourly buckets
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Simple priority list to boost common major cities (US-focused; extend as needed)
    private let majorCities: Set<String> = [
        "new york", "los angeles", "chicago", "houston", "phoenix", "philadelphia", "san antonio", "san diego", "dallas", "san jose",
        "austin", "jacksonville", "fort worth", "columbus", "san francisco", "charlotte", "indianapolis", "seattle", "denver", "washington",
        "boston", "el paso", "nashville", "detroit", "oklahoma city", "portland", "las vegas", "memphis", "louisville", "baltimore"
    ]
    
    init() {
        setupSearchDebouncing()
    }
    
    // MARK: - Search Functionality
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Cancel previous search task
        searchTask?.cancel()
        
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await searchLocations(query: trimmed)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.isSearching = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Search failed: \(error.localizedDescription)"
                        self.showError = true
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    private func searchLocations(query: String) async throws -> [LocationSearchResult] {
        // Use MapKit search, but restrict to addresses and prefer city-level results
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes = [.address] // avoid generic queries and POIs
        let search = MKLocalSearch(request: req)
        let resp = try await search.start()
        
        // Transform to city-level results only (must have a locality/city)
        var cityItems: [MKMapItem] = resp.mapItems.filter { item in
            let pm = item.placemark
            let hasCity = !(pm.locality ?? "").isEmpty
            // Exclude pure country-level results (no city, no admin area)
            return hasCity
        }
        
        // Rank results: prefix matches first, then major cities boost, then shorter title/locality
        let normalizedQuery = normalize(query)
        cityItems.sort { a, b in
            score(item: a, query: normalizedQuery) > score(item: b, query: normalizedQuery)
        }
        
        return cityItems.map { item in
            let pm = item.placemark
            return LocationSearchResult(
                name: item.name ?? pm.locality ?? "Unknown Location",
                locality: pm.locality ?? "",
                administrativeArea: pm.administrativeArea ?? "",
                country: pm.country ?? "",
                coordinate: pm.coordinate
            )
        }
    }
    
    private func score(item: MKMapItem, query: String) -> Int {
        let pm = item.placemark
        let title = normalize(item.name ?? pm.locality ?? "")
        let locality = normalize(pm.locality ?? "")
        let admin = normalize(pm.administrativeArea ?? "")
        
        var s = 0
        // Strongly prefer prefix matches on title or city name
        if title.hasPrefix(query) { s += 40 }
        if locality.hasPrefix(query) { s += 40 }
        // Secondary: contains match
        if title.contains(query) { s += 10 }
        if locality.contains(query) { s += 10 }
        // Boost for major cities
        if majorCities.contains(locality) || majorCities.contains(title) { s += 20 }
        // Small boost if same admin contains query (e.g., typing "phx az")
        if admin.contains(query) { s += 4 }
        // Slight penalty for very long titles
        s -= min(title.count / 10, 3)
        return s
    }
    
    private func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Location Selection
    
    func selectLocation(_ location: LocationSearchResult) {
        selectedLocation = location
        searchText = location.displayName
        searchResults = []
        fetchUVDataForLocation(location)
    }
    
    func clearSelection() {
        selectedLocation = nil
        selectedLocationUVData = nil
        selectedLocationHourlyUVData = []
        selectedLocationDailyUVData = []
        searchText = ""
        searchResults = []
    }
    
    // MARK: - UV Data Fetching
    
    private func fetchUVDataForLocation(_ location: LocationSearchResult) {
        isLoading = true
        
        Task {
            do {
                let coordinate = location.coordinate
                let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                let (currentWeather, hourlyForecast, _) = try await weatherService.weather(
                    for: clLocation,
                    including: .current,
                    .hourly,
                    .daily
                )
                
                // Build 7-day hourly buckets from hourlyForecast
                let calendar = Calendar.current
                var dailyBuckets: [[UVData]] = []
                for dayOffset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) else { continue }
                    let hoursForDay = hourlyForecast.filter { calendar.isDate($0.date, inSameDayAs: day) }
                    dailyBuckets.append(hoursForDay.map { UVData(from: $0) })
                }
                
                await MainActor.run {
                    self.selectedLocationUVData = UVData(from: currentWeather)
                    self.selectedLocationHourlyUVData = hourlyForecast.prefix(24).map { UVData(from: $0) }
                    self.selectedLocationDailyUVData = dailyBuckets
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch UV data: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func getCurrentUVIndex() -> Int {
        return selectedLocationUVData?.uvIndex ?? 0
    }
    
    func getUVColor() -> Color {
        return UVColorUtils.getUVColor(getCurrentUVIndex())
    }
    
    func getTimeToBurnString() -> String {
        let uvIndex = getCurrentUVIndex()
        return UnitConverter.shared.formatTimeToBurn(uvIndex)
    }
}

// MARK: - Location Search Result Model

struct LocationSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let locality: String
    let administrativeArea: String
    let country: String
    let coordinate: CLLocationCoordinate2D
    
    var displayName: String {
        if !locality.isEmpty && !administrativeArea.isEmpty {
            return "\(locality), \(administrativeArea)"
        } else if !locality.isEmpty {
            return locality
        } else if !administrativeArea.isEmpty {
            return administrativeArea
        } else {
            return name
        }
    }
    
    var fullDisplayName: String {
        var components: [String] = []
        
        if !locality.isEmpty {
            components.append(locality)
        }
        if !administrativeArea.isEmpty {
            components.append(administrativeArea)
        }
        if !country.isEmpty {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        return lhs.id == rhs.id
    }
} 