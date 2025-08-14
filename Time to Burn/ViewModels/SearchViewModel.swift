import Foundation
import CoreLocation
import WeatherKit
import Combine
import MapKit
import SwiftUI

// MARK: - TimeZone Extension for Coordinate-based Calculation
extension TimeZone {
    /// Calculates time zone based on longitude coordinates
    /// This is a rough approximation but more reliable than reverse geocoding
    init?(coordinate: CLLocationCoordinate2D) {
        // Basic calculation: longitude / 15 gives approximate time zone offset
        // Each 15 degrees of longitude roughly equals 1 hour
        let rawOffset = Int(round(coordinate.longitude / 15.0))
        let offsetHours = max(-12, min(12, rawOffset)) // Clamp to valid range
        let offsetSeconds = offsetHours * 3600
        
        // Try to find a named time zone close to this offset
        let targetOffset = offsetSeconds
        let allTimeZones = TimeZone.knownTimeZoneIdentifiers
        
        // Find the best matching time zone
        var bestMatch: TimeZone?
        var smallestDifference = Int.max
        
        for tzIdentifier in allTimeZones {
            if let tz = TimeZone(identifier: tzIdentifier) {
                let currentOffset = tz.secondsFromGMT(for: Date())
                let difference = abs(currentOffset - targetOffset)
                if difference < smallestDifference {
                    smallestDifference = difference
                    bestMatch = tz
                }
            }
        }
        
        if let match = bestMatch {
            self = match
        } else {
            // Fallback to GMT offset
            if let fallback = TimeZone(secondsFromGMT: offsetSeconds) {
                self = fallback
            } else {
                return nil
            }
        }
    }
}

@MainActor
class SearchViewModel: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [LocationSearchResult] = []
    @Published var celestialSearchResults: [CelestialBody] = []
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var selectedLocation: LocationSearchResult?
    @Published var selectedCelestialBody: CelestialBody?
    @Published var selectedLocationUVData: UVData?
    @Published var selectedLocationHourlyUVData: [UVData] = []
    @Published var selectedLocationDailyUVData: [[UVData]] = [] // 7-day hourly buckets
    @Published var selectedLocationTimeZone: TimeZone?
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var searchHistory: [LocationSearchResult] = []
    
    private let weatherService = WeatherService.shared
    private let celestialBodyService = CelestialBodyService.shared
    private let geocoder = CLGeocoder()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Lightweight LRU cache to provide instant results while refreshing in background
    private let resultsCache = LRUCache<String, [LocationSearchResult]>(capacity: 100)
    
    // History persistence
    private let historyDefaultsKey = "searchHistory.v1"
    private let maxHistoryCount = 20
    
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
        loadHistory()
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
            celestialSearchResults = []
            isSearching = false
            return
        }
        
        // Show live suggestions immediately for short queries (1–2 chars)
        if trimmed.count < 3 {
            isSearching = false
            searchResults = []
            celestialSearchResults = []
            // Bias suggestions to user's vicinity if available
            if let region = userSearchRegion() {
                completer.region = region
            }
            completer.queryFragment = trimmed
            return
        }
        
        // 3+ characters: run full location search with city filtering and ranking
        isSearching = true
        suggestions = []
        searchTask?.cancel()
        // Serve cached results instantly if available while refreshing in background
        let normalized = normalize(trimmed)
        if let cached = resultsCache.value(forKey: normalized), !cached.isEmpty {
            self.searchResults = cached
        }
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Search both locations and celestial bodies
                async let locationResults = try searchLocations(query: trimmed)
                let celestialResults = celestialBodyService.searchCelestialBodies(query: trimmed)
                
                let results = try await locationResults
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.celestialSearchResults = celestialResults
                        self.isSearching = false
                        // Update cache
                        self.resultsCache.setValue(results, forKey: normalized)
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
        let normalizedQuery = normalize(query)
        
        // Run MKLocalSearch and CLGeocoder in parallel, then merge
        async let mkResults: [LocationSearchResult] = fetchMapKitResults(query: query)
        async let geoResults: [LocationSearchResult] = geocodeResults(query: query)
        
        var combined = await (mkResults + geoResults)
        combined = deduplicateLocations(combined)
        
        // Final ranking
        let ranked = combined.sorted { a, b in
            score(result: a, query: normalizedQuery) > score(result: b, query: normalizedQuery)
        }
        
        return ranked
    }

    private func fetchMapKitResults(query: String) async -> [LocationSearchResult] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        // Include both address and POIs to capture administrative/locality entities globally
        req.resultTypes = [.address, .pointOfInterest]
        // Do NOT constrain to user region for full queries; we want global cities
        // Keep region bias only for 1–2 char suggestions
        do {
            let resp = try await MKLocalSearch(request: req).start()
            let items = resp.mapItems.filter { isLikelyCityMapItem($0) }
            return items.map { item in
                let pm = item.placemark
                return LocationSearchResult(
                    name: item.name ?? pm.locality ?? pm.administrativeArea ?? pm.country ?? "Unknown",
                    locality: pm.locality ?? "",
                    administrativeArea: pm.administrativeArea ?? "",
                    country: pm.country ?? "",
                    coordinate: pm.coordinate
                )
            }
        } catch {
            return []
        }
    }

    private func geocodeResults(query: String) async -> [LocationSearchResult] {
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.compactMap { pm in
                guard let location = pm.location else { return nil }
                return LocationSearchResult(
                    name: pm.locality ?? pm.name ?? pm.administrativeArea ?? pm.country ?? query,
                    locality: pm.locality ?? "",
                    administrativeArea: pm.administrativeArea ?? "",
                    country: pm.country ?? "",
                    coordinate: location.coordinate
                )
            }
        } catch {
            return []
        }
    }

    private func isLikelyCityMapItem(_ item: MKMapItem) -> Bool {
        let pm = item.placemark
        let title = normalize(item.name ?? pm.locality ?? pm.administrativeArea ?? pm.country ?? "")
        if title.isEmpty { return false }
        // Exclude obvious street-like results by keywords or digits
        if title.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        let tokens = Set(title.split(separator: " ").map { String($0) })
        if !streetKeywords.isDisjoint(with: tokens) { return false }
        // Accept if any of these are present
        return !(pm.locality ?? "").isEmpty || !(pm.administrativeArea ?? "").isEmpty || !(pm.country ?? "").isEmpty
    }

    private func deduplicateLocations(_ results: [LocationSearchResult]) -> [LocationSearchResult] {
        var unique: [LocationSearchResult] = []
        for r in results {
            if !unique.contains(where: { $0.isSamePlace(as: r) }) {
                unique.append(r)
            }
        }
        return unique
    }

    private func score(result: LocationSearchResult, query: String) -> Int {
        // Reuse the text+population+proximity scoring via a synthetic MKMapItem-like evaluation
        var s = 0
        let title = normalize(result.name)
        let locality = normalize(result.locality)
        if title == query { s += 50 }
        if title.hasPrefix(query) { s += 40 }
        if locality.hasPrefix(query) { s += 40 }
        if title.contains(query) { s += 10 }
        if locality.contains(query) { s += 10 }
        if majorCities.contains(locality) || majorCities.contains(title) { s += 20 }
        s -= min(title.count / 10, 3)
        // Population
        let pop = CityPopulationIndex.shared.population(for: result.locality.isEmpty ? result.name : result.locality, country: result.country)
        let qlen = max(1, min(query.count, 6))
        let popScale: Int = (qlen == 1 ? 30 : qlen == 2 ? 24 : qlen == 3 ? 18 : qlen == 4 ? 12 : qlen == 5 ? 8 : 6)
        s += CityPopulationIndex.shared.populationScore(population: pop, scale: popScale)
        // Proximity
        s += proximityScore(to: result.coordinate, queryLength: qlen)
        return s
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
        let proximity = proximityScore(to: item.placemark.coordinate, queryLength: qlen)
        return text + popScore + proximity
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

        // Add proximity bias for suggestions as well (strong only for very short queries)
        if let region = userSearchRegion() {
            let center = region.center
            // If suggestion subtitle has a locality/state hint, lightly boost when near
            let approxCoord = center // without resolving suggestion, use center only to avoid network
            let prox = proximityScore(to: approxCoord, queryLength: qlen)
            // scale down since we don't have exact coordinates for completion
            s += prox / 2
        }

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
    
    // MARK: - Proximity and Region Biasing
    
    private func userSearchRegion() -> MKCoordinateRegion? {
        if let loc = LocationManager.shared.location?.coordinate {
            // A moderate span to bias nearby results while still allowing discovery
            let span = MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            return MKCoordinateRegion(center: loc, span: span)
        }
        return nil
    }
    
    private func proximityScore(to coordinate: CLLocationCoordinate2D?, queryLength: Int) -> Int {
        guard let target = coordinate, let user = LocationManager.shared.location else { return 0 }
        let distanceMeters = CLLocation(latitude: target.latitude, longitude: target.longitude)
            .distance(from: user)
        let distanceKm = max(1.0, distanceMeters / 1000.0)
        // Convert distance to a diminishing score. Closer = higher
        // ~0-100km: strong, 100-1000km: moderate, >1000km: low
        let base = max(0.0, 30.0 - log10(distanceKm) * 12.0)
        // Short queries give proximity more influence
        let multiplier: Double
        switch queryLength {
        case 1: multiplier = 1.2
        case 2: multiplier = 1.0
        case 3: multiplier = 0.8
        case 4: multiplier = 0.6
        default: multiplier = 0.4
        }
        return Int(base * multiplier)
    }
    
    // MARK: - Location Selection
    
    func selectLocation(_ location: LocationSearchResult) {
        selectedLocation = location
        searchText = location.displayName
        suggestions = []
        searchResults = []
        addToHistory(location)
        
        // Start loading immediately
        isLoading = true
        
        // Fetch time zone first, then UV data
        fetchTimeZoneAndUVData(for: location)
    }
    
    private func fetchTimeZoneAndUVData(for location: LocationSearchResult) {
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Try to get time zone using coordinate-based approach first (more reliable)
        let timeZone = TimeZone(coordinate: location.coordinate)
        if let timeZone = timeZone {
            print("🌍 [SearchViewModel] ✅ Time zone calculated: \(timeZone.identifier) for \(location.displayName)")
            DispatchQueue.main.async {
                self.selectedLocationTimeZone = timeZone
                self.fetchUVDataForLocation(location)
            }
        } else {
            // Fallback to reverse geocoding
            geocoder.reverseGeocodeLocation(clLocation) { [weak self] placemarks, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        print("🌍 [SearchViewModel] ❌ Error fetching time zone: \(error)")
                        self.selectedLocationTimeZone = TimeZone(secondsFromGMT: 0)
                    } else if let timeZone = placemarks?.first?.timeZone {
                        print("🌍 [SearchViewModel] ✅ Time zone from geocoding: \(timeZone.identifier)")
                        self.selectedLocationTimeZone = timeZone
                    } else {
                        print("🌍 [SearchViewModel] ⚠️ Using GMT fallback")
                        self.selectedLocationTimeZone = TimeZone(secondsFromGMT: 0)
                    }
                    self.fetchUVDataForLocation(location)
                }
            }
        }
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
        selectedCelestialBody = nil
        selectedLocationUVData = nil
        selectedLocationHourlyUVData = []
        selectedLocationDailyUVData = []
        selectedLocationTimeZone = nil
        searchText = ""
        suggestions = []
        searchResults = []
        celestialSearchResults = []
    }
    
    // MARK: - Celestial Body Selection
    
    func selectCelestialBody(_ celestialBody: CelestialBody) {
        selectedCelestialBody = celestialBody
        selectedLocation = nil // Clear any location selection
        searchText = celestialBody.displayName
        suggestions = []
        searchResults = []
        celestialSearchResults = []
        
        // Generate mock UV data for celestial bodies
        generateCelestialUVData(for: celestialBody)
    }
    
    private func generateCelestialUVData(for celestialBody: CelestialBody) {
        isLoading = true
        
        // For space objects, we'll create constant UV data since they don't have weather patterns
        let currentTime = Date()
        let calendar = Calendar.current
        
        // Create 24 hours of data with constant UV
        var hourlyData: [UVData] = []
        for hour in 0..<24 {
            if let hourDate = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: currentTime)) {
                hourlyData.append(UVData(uvIndex: celestialBody.uvIndex, date: hourDate))
            }
        }
        
        // Create 7 days of data
        var dailyBuckets: [[UVData]] = []
        for dayOffset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: currentTime)) {
                var dayData: [UVData] = []
                for hour in 0..<24 {
                    if let hourDate = calendar.date(byAdding: .hour, value: hour, to: day) {
                        dayData.append(UVData(uvIndex: celestialBody.uvIndex, date: hourDate))
                    }
                }
                dailyBuckets.append(dayData)
            }
        }
        
        // Update UI
        selectedLocationUVData = UVData(uvIndex: celestialBody.uvIndex, date: currentTime)
        selectedLocationHourlyUVData = hourlyData
        selectedLocationDailyUVData = dailyBuckets
        selectedLocationTimeZone = nil // Space objects don't have time zones
        isLoading = false
    }

    // MARK: - Search History
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([LocationSearchResult].self, from: data)
            self.searchHistory = decoded
        } catch {
            // If decoding fails, clear saved data
            UserDefaults.standard.removeObject(forKey: historyDefaultsKey)
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(searchHistory)
            UserDefaults.standard.set(data, forKey: historyDefaultsKey)
        } catch {
            // Ignore save errors for history
        }
    }
    
    private func addToHistory(_ location: LocationSearchResult) {
        if let idx = searchHistory.firstIndex(where: { $0.isSamePlace(as: location) }) {
            searchHistory.remove(at: idx)
        }
        searchHistory.insert(location, at: 0)
        if searchHistory.count > maxHistoryCount {
            searchHistory.removeLast(searchHistory.count - maxHistoryCount)
        }
        saveHistory()
    }
    
    func removeFromHistory(at offsets: IndexSet) {
        searchHistory.remove(atOffsets: offsets)
        saveHistory()
    }
    
    func removeFromHistory(id: UUID) {
        if let idx = searchHistory.firstIndex(where: { $0.id == id }) {
            searchHistory.remove(at: idx)
            saveHistory()
        }
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

struct LocationSearchResult: Identifiable, Hashable, Codable {
    let id: UUID
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
    
    func isSamePlace(as other: LocationSearchResult) -> Bool {
        // Compare by locality/admin/country and close coordinates
        let sameText = self.locality == other.locality && self.administrativeArea == other.administrativeArea && self.country == other.country
        let dLat = abs(self.coordinate.latitude - other.coordinate.latitude)
        let dLon = abs(self.coordinate.longitude - other.coordinate.longitude)
        return sameText && dLat < 0.0001 && dLon < 0.0001
    }
} 

// MARK: - Codable for CLLocationCoordinate2D
extension LocationSearchResult {
    private enum CodingKeys: String, CodingKey {
        case id, name, locality, administrativeArea, country, latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let name = try c.decode(String.self, forKey: .name)
        let locality = try c.decode(String.self, forKey: .locality)
        let administrativeArea = try c.decode(String.self, forKey: .administrativeArea)
        let country = try c.decode(String.self, forKey: .country)
        let lat = try c.decode(CLLocationDegrees.self, forKey: .latitude)
        let lon = try c.decode(CLLocationDegrees.self, forKey: .longitude)
        self.id = id
        self.name = name
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(locality, forKey: .locality)
        try c.encode(administrativeArea, forKey: .administrativeArea)
        try c.encode(country, forKey: .country)
        try c.encode(coordinate.latitude, forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
    }
    
    // Convenience init used by UI code; preserves prior call sites
    init(name: String, locality: String, administrativeArea: String, country: String, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.name = name
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.coordinate = coordinate
    }
}
