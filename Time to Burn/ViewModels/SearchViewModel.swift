import Foundation
import CoreLocation
import WeatherKit
import Combine
import MapKit
import SwiftUI

@MainActor
class SearchViewModel: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [LocationSearchResult] = []
    @Published var suggestions: [MKLocalSearchCompletion] = []
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
    
    // Fast suggestions provider (appears from first character)
    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address] // focus on locations/addresses
        return c
    }()
    
    // Simple priority list to boost common major cities (US-focused; extend as needed)
    private let majorCities: Set<String> = [
        "new york", "los angeles", "chicago", "houston", "phoenix", "philadelphia", "san antonio", "san diego", "dallas", "san jose",
        "austin", "jacksonville", "fort worth", "columbus", "san francisco", "charlotte", "indianapolis", "seattle", "denver", "washington",
        "boston", "el paso", "nashville", "detroit", "oklahoma city", "portland", "las vegas", "memphis", "louisville", "baltimore"
    ]
    
    // Heuristics to exclude streets and states from suggestions
    private let streetKeywords: Set<String> = [
        "st", "street", "ave", "avenue", "rd", "road", "dr", "drive", "blvd", "boulevard", "ln", "lane", "ct", "court", "pl", "place", "ter", "terrace", "hwy", "highway", "way", "pkwy", "parkway"
    ]
    private let countryKeywords: Set<String> = [
        "united states", "usa", "canada", "mexico", "united kingdom", "uk", "australia", "germany", "france", "italy", "spain", "japan", "china", "india"
    ]
    private let stateAbbreviations: Set<String> = [
        "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"
    ]
    
    override init() {
        super.init()
        completer.delegate = self
        setupSearchDebouncing()
    }
    
    // MARK: - Search Functionality
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            searchResults = []
            isSearching = false
            return
        }
        
        // Show live suggestions immediately for short queries (1–2 chars)
        if trimmed.count < 3 {
            isSearching = false
            searchResults = []
            completer.queryFragment = trimmed
            return
        }
        
        // 3+ characters: run full location search with city filtering and ranking
        isSearching = true
        suggestions = []
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
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes = [.address]
        let search = MKLocalSearch(request: req)
        let resp = try await search.start()
        
        // City-level only
        var cityItems: [MKMapItem] = resp.mapItems.filter { item in
            let pm = item.placemark
            let hasCity = !(pm.locality ?? "").isEmpty
            return hasCity
        }
        
        let normalizedQuery = normalize(query)
        cityItems.sort { a, b in
            rankedScore(item: a, query: normalizedQuery) > rankedScore(item: b, query: normalizedQuery)
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
    
    /// Composite score combining textual relevance and population weight.
    /// For short queries (1-2 chars), population weight is stronger.
    /// As query length grows, textual relevance dominates.
    private func rankedScore(item: MKMapItem, query: String) -> Int {
        let text = score(item: item, query: query)
        let pm = item.placemark
        let city = pm.locality ?? item.name ?? ""
        let country = pm.country
        let population = CityPopulationIndex.shared.population(for: city, country: country)

        // Weight scale: stronger when query is very short
        let qlen = max(1, min(query.count, 6))
        // qlen 1 -> 30, 2 -> 24, 3 -> 18, 4 -> 12, 5 -> 8, 6+ -> 6
        let populationScale: Int
        switch qlen {
        case 1: populationScale = 30
        case 2: populationScale = 24
        case 3: populationScale = 18
        case 4: populationScale = 12
        case 5: populationScale = 8
        default: populationScale = 6
        }

        let popScore = CityPopulationIndex.shared.populationScore(population: population, scale: populationScale)
        return text + popScore
    }

    private func score(item: MKMapItem, query: String) -> Int {
        let pm = item.placemark
        let title = normalize(item.name ?? pm.locality ?? "")
        let locality = normalize(pm.locality ?? "")
        let admin = normalize(pm.administrativeArea ?? "")
        
        var s = 0
        if title.hasPrefix(query) { s += 40 }
        if locality.hasPrefix(query) { s += 40 }
        if title.contains(query) { s += 10 }
        if locality.contains(query) { s += 10 }
        if majorCities.contains(locality) || majorCities.contains(title) { s += 20 }
        if admin.contains(query) { s += 4 }
        s -= min(title.count / 10, 3)
        return s
    }
    
    private func suggestionScore(_ c: MKLocalSearchCompletion, query: String) -> Int {
        let title = normalize(c.title)
        let subtitle = normalize(c.subtitle)
        var s = 0
        if title.hasPrefix(query) { s += 40 }
        if title.contains(query) { s += 10 }
        if majorCities.contains(title) { s += 20 }
        if subtitle.contains(query) { s += 5 }
        s -= min(title.count / 10, 3)

        // Add population weight to suggestions when query is very short
        // Attempt to parse city and country hints from title/subtitle
        let components = title.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let city = components.first ?? title
        // Country often present in subtitle after comma
        let countryFromSubtitle = subtitle.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespaces) }
        let pop = CityPopulationIndex.shared.population(for: city, country: countryFromSubtitle)
        let qlen = max(1, min(query.count, 6))
        let scale: Int = (qlen <= 2) ? 24 : (qlen == 3 ? 16 : 8)
        s += CityPopulationIndex.shared.populationScore(population: pop, scale: scale)

        return s
    }
    
    private func isLikelyCitySuggestion(_ c: MKLocalSearchCompletion) -> Bool {
        let title = normalize(c.title)
        let subtitle = normalize(c.subtitle)
        
        // Exclude if title contains digits (likely street addresses)
        if title.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        
        // Exclude obvious street keywords in title
        let titleTokens = Set(title.split(separator: " ").map { String($0) })
        if !streetKeywords.isDisjoint(with: titleTokens) { return false }
        
        // Exclude country-only and state-only entries
        if countryKeywords.contains(title) { return false }
        if stateAbbreviations.contains(title.uppercased()) { return false }
        // Single-word uppercase like "ARIZONA" heuristics
        if title.split(separator: " ").count == 1 && title.uppercased() == title && title.count <= 10 {
            return false
        }
        
        // Prefer entries that look like city, state in title or subtitle
        let looksLikeCityComma = title.contains(",") || subtitle.contains(",")
        return looksLikeCityComma || !subtitle.isEmpty
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
        suggestions = []
        searchResults = []
        fetchUVDataForLocation(location)
    }
    
    func selectSuggestion(_ completion: MKLocalSearchCompletion) {
        let req = MKLocalSearch.Request(completion: completion)
        req.resultTypes = [.address]
        isSearching = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let resp = try await MKLocalSearch(request: req).start()
                let query = self.normalize(completion.title)
                let cityItems = resp.mapItems.filter { !($0.placemark.locality ?? "").isEmpty }
                let ranked = cityItems.sorted { a, b in
                    self.score(item: a, query: query) > self.score(item: b, query: query)
                }
                if let best = ranked.first {
                    let pm = best.placemark
                    let loc = LocationSearchResult(
                        name: best.name ?? pm.locality ?? completion.title,
                        locality: pm.locality ?? completion.title,
                        administrativeArea: pm.administrativeArea ?? "",
                        country: pm.country ?? "",
                        coordinate: pm.coordinate
                    )
                    await MainActor.run {
                        self.selectLocation(loc)
                        self.isSearching = false
                    }
                } else {
                    await MainActor.run {
                        self.isSearching = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to resolve suggestion: \(error.localizedDescription)"
                    self.showError = true
                    self.isSearching = false
                }
            }
        }
    }
    
    func clearSelection() {
        selectedLocation = nil
        selectedLocationUVData = nil
        selectedLocationHourlyUVData = []
        selectedLocationDailyUVData = []
        searchText = ""
        suggestions = []
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

// MARK: - MKLocalSearchCompleterDelegate
extension SearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            let q = self.normalize(self.searchText)
            // Filter to likely city suggestions, then rank
            let filtered = completer.results
                .filter { !$0.title.isEmpty }
                .filter { self.isLikelyCitySuggestion($0) }
            let ranked = filtered.sorted { a, b in
                self.suggestionScore(a, query: q) > self.suggestionScore(b, query: q)
            }
            self.suggestions = ranked
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Suggestions failed: \(error.localizedDescription)"
            self.showError = false // don't alert for suggestions
        }
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
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool { lhs.id == rhs.id }
} 