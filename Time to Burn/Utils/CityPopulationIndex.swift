import Foundation

/// Provides approximate population-based weights for cities to improve search ranking.
/// This index is intentionally small and curated to cover major world cities and large US cities.
/// All lookups are normalized (diacritic-insensitive, lowercased, trimmed).
final class CityPopulationIndex {
    static let shared = CityPopulationIndex()

    private init() {}

    // Key format: "city|country" using normalized values.
    // Country may be omitted for globally unique cities.
    // Populations are approximate and intended only for relative ranking.
    private let popByCityCountry: [String: Int] = [
        // World major cities
        "tokyo|japan": 37400068,
        "delhi|india": 29399141,
        "shanghai|china": 26317104,
        "sao paulo|brazil": 21846507,
        "são paulo|brazil": 21846507,
        "mexico city|mexico": 21671908,
        "cairo|egypt": 20484965,
        "dhaka|bangladesh": 20283552,
        "beijing|china": 20035455,
        "mumbai|india": 19980000,
        "osaka|japan": 19281000,
        "chongqing|china": 15872000,
        "karachi|pakistan": 15400000,
        "buenos aires|argentina": 15100000,
        "istanbul|turkiye": 15067724,
        "kolkata|india": 14680000,
        "lagos|nigeria": 14200000,
        "manila|philippines": 13923452,
        "tianjin|china": 13210000,
        "rio de janeiro|brazil": 13458000,
        "guangzhou|china": 13081000,
        "shenzhen|china": 12530000,
        "lahore|pakistan": 12188000,
        "bangalore|india": 11440000,
        "bengaluru|india": 11440000,
        "paris|france": 11020000,
        "london|united kingdom": 9425622,
        "tehran|iran": 8846782,
        "bogota|colombia": 10777933,
        "bogotá|colombia": 10777933,
        "jakarta|indonesia": 10770487,
        "lima|peru": 9674755,
        "bangkok|thailand": 10539000,
        "kinshasa|dr congo": 14500000,
        "ho chi minh city|vietnam": 9046000,
        "chennai|india": 8865000,
        "hyderabad|india": 10040000,
        "wuhan|china": 9020000,
        "santiago|chile": 7000000,
        "riyadh|saudi arabia": 7670000,
        "madrid|spain": 6642000,
        "barcelona|spain": 5586000,
        "rome|italy": 4279000,
        "berlin|germany": 3769000,
        "toronto|canada": 6313000,
        "montreal|canada": 4212000,
        "montréal|canada": 4212000,
        "vancouver|canada": 2640000,
        "amsterdam|netherlands": 1158000,
        "brussels|belgium": 2081000,
        "zurich|switzerland": 1500000,
        "zürich|switzerland": 1500000,
        "vienna|austria": 1934000,
        "athens|greece": 3153000,
        "johannesburg|south africa": 5570000,
        "nairobi|kenya": 4500000,
        "cape town|south africa": 4600000,
        "casablanca|morocco": 3360000,
        "abu dhabi|united arab emirates": 1480000,
        "dubai|united arab emirates": 3331000,
        "doha|qatar": 956000,
        "singapore|singapore": 5639000,
        "hong kong|hong kong": 7451000,
        "seoul|south korea": 9776000,
        "taipei|taiwan": 2600000,
        "kuala lumpur|malaysia": 1780000,

        // United States (city proper populations approx.)
        "new york|united states": 8467513,
        "los angeles|united states": 3985529,
        "chicago|united states": 2714856,
        "houston|united states": 2320268,
        "phoenix|united states": 1690000,
        "philadelphia|united states": 1584203,
        "san antonio|united states": 1547253,
        "san diego|united states": 1423851,
        "dallas|united states": 1343573,
        "san jose|united states": 1021795,
        "austin|united states": 1000000,
        "jacksonville|united states": 911507,
        "fort worth|united states": 918915,
        "columbus|united states": 906528,
        "san francisco|united states": 881549,
        "charlotte|united states": 885708,
        "indianapolis|united states": 876384,
        "seattle|united states": 744955,
        "denver|united states": 716492,
        "washington|united states": 705749,
        "boston|united states": 692600,
        "el paso|united states": 681728,
        "nashville|united states": 670820,
        "detroit|united states": 672662,
        "oklahoma city|united states": 655057,
        "portland|united states": 653115,
        "las vegas|united states": 651319,
        "memphis|united states": 651073,
        "louisville|united states": 617638,
        "baltimore|united states": 593490,
        "milwaukee|united states": 590157,
        "albuquerque|united states": 560513,
        "tucson|united states": 545975,
        "fresno|united states": 531576,
        "sacramento|united states": 513624,
        "kansas city|united states": 508090,
        "mesa|united states": 508958,
        "atlanta|united states": 506811,
        "omaha|united states": 478961,
        "colorado springs|united states": 478221,
        "raleigh|united states": 474069,
        "miami|united states": 467963,
        "long beach|united states": 462628,
        "virginia beach|united states": 449974,
        "oakland|united states": 433031,
        "minneapolis|united states": 429954,
        "tulsa|united states": 401190,
        "tampa|united states": 399700,
        "new orleans|united states": 391006,
        "wichita|united states": 389938,
        "arlington|united states": 398854,
        "cleveland|united states": 372624,
        "bakersfield|united states": 383579,
        "aurora|united states": 384233,
        "anaheim|united states": 350365,
        "honolulu|united states": 345064,
        "santa ana|united states": 332318,
        "riverside|united states": 327728,
        "corpus christi|united states": 326332,
        "lexington|united states": 323780,
        "henderson|united states": 320189,
        "stockton|united states": 312697,
        "saint paul|united states": 307193,
        "cincinnati|united states": 302605,
        "saint louis|united states": 300576,
        "st. louis|united states": 300576,
        "pittsburgh|united states": 300286,
        "greensboro|united states": 296710,
        "lincoln|united states": 289102,
        "anchorage|united states": 288000,
        "plano|united states": 287677,
        "orlando|united states": 287442
    ]

    private func normalize(_ s: String) -> String {
        return s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns estimated population for a given city and optional country.
    func population(for city: String, country: String?) -> Int {
        let c = normalize(city)
        let countryNorm = country.map { normalize($0) }

        if let countryNorm, let exact = popByCityCountry["\(c)|\(countryNorm)"] {
            return exact
        }
        if let any = popByCityCountry[c] { // fallback if inserted without country
            return any
        }
        return 0
    }

    /// Converts population to an additive ranking score. Uses log10 to keep scale manageable.
    /// - Parameters:
    ///   - population: raw population (0 if unknown)
    ///   - scale: multiplier to tune the impact relative to text relevance
    func populationScore(population: Int, scale: Int) -> Int {
        guard population > 0 else { return 0 }
        let logv = log10(Double(population)) // ~6..8
        return Int(logv * Double(scale))
    }
}


