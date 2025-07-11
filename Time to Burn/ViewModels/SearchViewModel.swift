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
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearchDebouncing()
    }
    
    // MARK: - Search Functionality
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(searchText: String) {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Cancel previous search task
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                let results = try await searchLocations(query: searchText)
                
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
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: searchRequest)
        let response = try await search.start()
        
        return response.mapItems.map { item in
            LocationSearchResult(
                name: item.name ?? "Unknown Location",
                locality: item.placemark.locality ?? "",
                administrativeArea: item.placemark.administrativeArea ?? "",
                country: item.placemark.country ?? "",
                coordinate: item.placemark.coordinate
            )
        }
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
                
                await MainActor.run {
                    self.selectedLocationUVData = UVData(from: currentWeather)
                    self.selectedLocationHourlyUVData = hourlyForecast.prefix(24).map { UVData(from: $0) }
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