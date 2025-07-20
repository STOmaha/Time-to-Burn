import Foundation
import CoreLocation
import WeatherKit

// MARK: - Environmental Factors Data Model
struct EnvironmentalFactors: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let altitude: Double // meters above sea level
    let snowConditions: SnowConditions
    let waterProximity: WaterProximity
    let terrainType: TerrainType
    let seasonalFactors: SeasonalFactors
    
    enum CodingKeys: String, CodingKey {
        case timestamp, location, altitude, snowConditions, waterProximity, terrainType, seasonalFactors
    }
    
    init(
        location: CLLocationCoordinate2D,
        altitude: Double = 0,
        snowConditions: SnowConditions = SnowConditions(),
        waterProximity: WaterProximity = WaterProximity(),
        terrainType: TerrainType = .unknown,
        seasonalFactors: SeasonalFactors = SeasonalFactors()
    ) {
        self.timestamp = Date()
        self.location = location
        self.altitude = altitude
        self.snowConditions = snowConditions
        self.waterProximity = waterProximity
        self.terrainType = terrainType
        self.seasonalFactors = seasonalFactors
    }
    
    // Custom encoding for CLLocationCoordinate2D
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(snowConditions, forKey: .snowConditions)
        try container.encode(waterProximity, forKey: .waterProximity)
        try container.encode(terrainType, forKey: .terrainType)
        try container.encode(seasonalFactors, forKey: .seasonalFactors)
        
        // Encode location as separate lat/lng
        var locationContainer = container.nestedContainer(keyedBy: LocationCodingKeys.self, forKey: .location)
        try locationContainer.encode(location.latitude, forKey: .latitude)
        try locationContainer.encode(location.longitude, forKey: .longitude)
    }
    
    // Custom decoding for CLLocationCoordinate2D
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        altitude = try container.decode(Double.self, forKey: .altitude)
        snowConditions = try container.decode(SnowConditions.self, forKey: .snowConditions)
        waterProximity = try container.decode(WaterProximity.self, forKey: .waterProximity)
        terrainType = try container.decode(TerrainType.self, forKey: .terrainType)
        seasonalFactors = try container.decode(SeasonalFactors.self, forKey: .seasonalFactors)
        
        // Decode location from separate lat/lng
        let locationContainer = try container.nestedContainer(keyedBy: LocationCodingKeys.self, forKey: .location)
        let latitude = try locationContainer.decode(Double.self, forKey: .latitude)
        let longitude = try locationContainer.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private enum LocationCodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "altitude": altitude,
            "snowConditions": [
                "hasRecentSnowfall": snowConditions.hasRecentSnowfall,
                "snowDepth": snowConditions.snowDepth,
                "snowCoverage": snowConditions.snowCoverage,
                "snowAge": snowConditions.snowAge,
                "snowType": snowConditions.snowType.rawValue
            ],
            "waterProximity": [
                "distanceToWater": waterProximity.distanceToWater,
                "waterBodyType": waterProximity.waterBodyType.rawValue,
                "nearestWaterBody": waterProximity.nearestWaterBody?.toDictionary() ?? [:]
            ],
            "terrainType": terrainType.rawValue,
            "seasonalFactors": [
                "season": seasonalFactors.season.rawValue,
                "dayOfYear": seasonalFactors.dayOfYear,
                "isWinterSolstice": seasonalFactors.isWinterSolstice,
                "isSummerSolstice": seasonalFactors.isSummerSolstice,
                "isEquinox": seasonalFactors.isEquinox,
                "seasonalUVMultiplier": seasonalFactors.seasonalUVMultiplier
            ]
        ]
    }
}

// MARK: - Snow Conditions
struct SnowConditions: Codable {
    let hasRecentSnowfall: Bool
    let snowDepth: Double // centimeters
    let snowCoverage: Double // percentage (0-100)
    let snowAge: Int // days since last snowfall
    let snowType: SnowType
    
    init(
        hasRecentSnowfall: Bool = false,
        snowDepth: Double = 0,
        snowCoverage: Double = 0,
        snowAge: Int = 0,
        snowType: SnowType = .none
    ) {
        self.hasRecentSnowfall = hasRecentSnowfall
        self.snowDepth = snowDepth
        self.snowCoverage = snowCoverage
        self.snowAge = snowAge
        self.snowType = snowType
    }
    
    enum SnowType: String, Codable, CaseIterable {
        case none = "None"
        case fresh = "Fresh"
        case packed = "Packed"
        case melting = "Melting"
        case icy = "Icy"
        
        var reflectionFactor: Double {
            switch self {
            case .none: return 0.0
            case .fresh: return 0.8 // 80% UV reflection
            case .packed: return 0.6 // 60% UV reflection
            case .melting: return 0.4 // 40% UV reflection
            case .icy: return 0.7 // 70% UV reflection
            }
        }
        
        var description: String {
            switch self {
            case .none: return "No snow"
            case .fresh: return "Fresh snow - high UV reflection"
            case .packed: return "Packed snow - moderate UV reflection"
            case .melting: return "Melting snow - reduced UV reflection"
            case .icy: return "Icy conditions - high UV reflection"
            }
        }
    }
}

// MARK: - Water Proximity
struct WaterProximity: Codable {
    let nearestWaterBody: WaterBody?
    let distanceToWater: Double // meters
    let waterBodyType: WaterBodyType
    let isCoastal: Bool
    let coastalDistance: Double? // meters to coastline
    
    init(
        nearestWaterBody: WaterBody? = nil,
        distanceToWater: Double = Double.infinity,
        waterBodyType: WaterBodyType = .none,
        isCoastal: Bool = false,
        coastalDistance: Double? = nil
    ) {
        self.nearestWaterBody = nearestWaterBody
        self.distanceToWater = distanceToWater
        self.waterBodyType = waterBodyType
        self.isCoastal = isCoastal
        self.coastalDistance = coastalDistance
    }
    
    struct WaterBody: Codable {
        let name: String
        let type: WaterBodyType
        let size: WaterBodySize
        let coordinates: CLLocationCoordinate2D
        
        enum CodingKeys: String, CodingKey {
            case name, type, size, coordinates
        }
        
        init(name: String, type: WaterBodyType, size: WaterBodySize, coordinates: CLLocationCoordinate2D) {
            self.name = name
            self.type = type
            self.size = size
            self.coordinates = coordinates
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(type, forKey: .type)
            try container.encode(size, forKey: .size)
            
            var coordContainer = container.nestedContainer(keyedBy: CoordCodingKeys.self, forKey: .coordinates)
            try coordContainer.encode(coordinates.latitude, forKey: .latitude)
            try coordContainer.encode(coordinates.longitude, forKey: .longitude)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(WaterBodyType.self, forKey: .type)
            size = try container.decode(WaterBodySize.self, forKey: .size)
            
            let coordContainer = try container.nestedContainer(keyedBy: CoordCodingKeys.self, forKey: .coordinates)
            let latitude = try coordContainer.decode(Double.self, forKey: .latitude)
            let longitude = try coordContainer.decode(Double.self, forKey: .longitude)
            coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        private enum CoordCodingKeys: String, CodingKey {
            case latitude, longitude
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "name": name,
                "type": type.rawValue,
                "size": size.rawValue,
                "coordinates": [
                    "latitude": coordinates.latitude,
                    "longitude": coordinates.longitude
                ]
            ]
        }
    }
    
    enum WaterBodyType: String, Codable, CaseIterable {
        case none = "None"
        case ocean = "Ocean"
        case sea = "Sea"
        case lake = "Lake"
        case river = "River"
        case stream = "Stream"
        case pond = "Pond"
        case pool = "Pool"
        
        var reflectionFactor: Double {
            switch self {
            case .none: return 0.0
            case .ocean, .sea: return 0.25 // 25% UV reflection
            case .lake: return 0.20 // 20% UV reflection
            case .river: return 0.15 // 15% UV reflection
            case .stream: return 0.10 // 10% UV reflection
            case .pond: return 0.18 // 18% UV reflection
            case .pool: return 0.12 // 12% UV reflection
            }
        }
        
        var description: String {
            switch self {
            case .none: return "No water nearby"
            case .ocean: return "Ocean - high UV reflection"
            case .sea: return "Sea - high UV reflection"
            case .lake: return "Lake - moderate UV reflection"
            case .river: return "River - moderate UV reflection"
            case .stream: return "Stream - low UV reflection"
            case .pond: return "Pond - moderate UV reflection"
            case .pool: return "Pool - low UV reflection"
            }
        }
    }
    
    enum WaterBodySize: String, Codable, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case massive = "Massive"
        
        var sizeMultiplier: Double {
            switch self {
            case .small: return 0.5
            case .medium: return 0.75
            case .large: return 1.0
            case .massive: return 1.25
            }
        }
    }
}

// MARK: - Terrain Type
enum TerrainType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case coastal = "Coastal"
    case mountainous = "Mountainous"
    case urban = "Urban"
    case rural = "Rural"
    case desert = "Desert"
    case forest = "Forest"
    case grassland = "Grassland"
    case arctic = "Arctic"
    
    var altitudeMultiplier: Double {
        switch self {
        case .unknown: return 1.0
        case .coastal: return 1.05 // Slight increase due to water reflection
        case .mountainous: return 1.15 // Significant increase due to altitude
        case .urban: return 1.0 // No change
        case .rural: return 1.02 // Slight increase due to less pollution
        case .desert: return 1.10 // High increase due to sand reflection
        case .forest: return 0.95 // Decrease due to tree cover
        case .grassland: return 1.03 // Slight increase
        case .arctic: return 1.20 // High increase due to snow and altitude
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "Unknown terrain"
        case .coastal: return "Coastal area - water reflection increases UV"
        case .mountainous: return "Mountainous terrain - altitude increases UV"
        case .urban: return "Urban area - buildings may provide shade"
        case .rural: return "Rural area - open exposure to sun"
        case .desert: return "Desert - sand reflection increases UV"
        case .forest: return "Forest - tree cover reduces UV"
        case .grassland: return "Grassland - open exposure to sun"
        case .arctic: return "Arctic - snow reflection and altitude increase UV"
        }
    }
}

// MARK: - Seasonal Factors
struct SeasonalFactors: Codable {
    let season: Season
    let dayOfYear: Int
    let isWinterSolstice: Bool
    let isSummerSolstice: Bool
    let isEquinox: Bool
    let seasonalUVMultiplier: Double
    
    init(
        season: Season = .unknown,
        dayOfYear: Int = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1,
        isWinterSolstice: Bool = false,
        isSummerSolstice: Bool = false,
        isEquinox: Bool = false,
        seasonalUVMultiplier: Double = 1.0
    ) {
        self.season = season
        self.dayOfYear = dayOfYear
        self.isWinterSolstice = isWinterSolstice
        self.isSummerSolstice = isSummerSolstice
        self.isEquinox = isEquinox
        self.seasonalUVMultiplier = seasonalUVMultiplier
    }
    
    enum Season: String, Codable, CaseIterable {
        case spring = "Spring"
        case summer = "Summer"
        case autumn = "Autumn"
        case winter = "Winter"
        case unknown = "Unknown"
        
        var uvMultiplier: Double {
            switch self {
            case .spring: return 0.8
            case .summer: return 1.0
            case .autumn: return 0.7
            case .winter: return 0.5
            case .unknown: return 1.0
            }
        }
        
        var description: String {
            switch self {
            case .spring: return "Spring - moderate UV levels"
            case .summer: return "Summer - peak UV levels"
            case .autumn: return "Autumn - declining UV levels"
            case .winter: return "Winter - lowest UV levels"
            case .unknown: return "Unknown season"
            }
        }
    }
} 