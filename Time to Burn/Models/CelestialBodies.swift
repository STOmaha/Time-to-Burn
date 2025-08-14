import Foundation
import CoreLocation

// MARK: - Celestial Body Models

enum CelestialBodyType {
    case planet
    case moon
    case satellite
    case spaceStation
    case telescope
}

struct CelestialBody: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: CelestialBodyType
    let uvIndex: Int
    let distanceFromSun: Double? // AU (Astronomical Units)
    let description: String
    let yearLaunched: Int? // For satellites/stations
    let orbitType: String? // For satellites
    let funFact: String
    
    init(name: String, type: CelestialBodyType, uvIndex: Int, distanceFromSun: Double? = nil, description: String, yearLaunched: Int? = nil, orbitType: String? = nil, funFact: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.uvIndex = uvIndex
        self.distanceFromSun = distanceFromSun
        self.description = description
        self.yearLaunched = yearLaunched
        self.orbitType = orbitType
        self.funFact = funFact
    }
    
    var displayName: String {
        return name
    }
    
    var fullDisplayName: String {
        switch type {
        case .planet:
            if let distance = distanceFromSun {
                return "\(name) • \(String(format: "%.3f", distance)) AU from Sun"
            }
            return name
        case .moon:
            return "\(name) • Earth's natural satellite"
        case .satellite, .spaceStation:
            if let year = yearLaunched {
                return "\(name) • Launched \(year)"
            }
            return name
        case .telescope:
            if let year = yearLaunched {
                return "\(name) • Deep space telescope • \(year)"
            }
            return "\(name) • Deep space telescope"
        }
    }
    
    var emoji: String {
        switch type {
        case .planet:
            switch name.lowercased() {
            case "mercury": return "☿️"
            case "venus": return "♀️"
            case "mars": return "🔴"
            case "jupiter": return "🪐"
            case "saturn": return "🪐"
            case "uranus": return "🔵"
            case "neptune": return "🔵"
            default: return "🌍"
            }
        case .moon:
            return "🌙"
        case .satellite:
            return "🛰️"
        case .spaceStation:
            return "🚀"
        case .telescope:
            return "🔭"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CelestialBody, rhs: CelestialBody) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Celestial Body Service

@MainActor
class CelestialBodyService: ObservableObject {
    static let shared = CelestialBodyService()
    
    private let celestialBodies: [CelestialBody] = [
        // MARK: - Planets
        CelestialBody(
            name: "Mercury",
            type: .planet,
            uvIndex: 330,
            distanceFromSun: 0.387,
            description: "Closest planet to the Sun",
            funFact: "No meaningful atmosphere means UV hits the surface at full vacuum intensity - you'd be instantly fried! ☿️🔥"
        ),
        
        CelestialBody(
            name: "Venus",
            type: .planet,
            uvIndex: 0,
            distanceFromSun: 0.723,
            description: "Thick sulfuric acid clouds block all UV",
            funFact: "The 20km-thick sulfuric acid cloud deck means UV never reaches the surface - but you'd melt from 462°C heat first! ♀️🌫️"
        ),
        
        CelestialBody(
            name: "Mars",
            type: .planet,
            uvIndex: 18,
            distanceFromSun: 1.524,
            description: "Thin atmosphere offers little UV protection",
            funFact: "NASA's Curiosity rover consistently measures 'extreme' UV levels - bring SPF 1000+ for your Mars vacation! 🔴🤖"
        ),
        
        CelestialBody(
            name: "Jupiter",
            type: .planet,
            uvIndex: 2,
            distanceFromSun: 5.20,
            description: "Gas giant with thick atmosphere",
            funFact: "You'd float in the thick atmosphere at cloud level - UV is low but you'd be crushed by pressure! 🪐💨"
        ),
        
        CelestialBody(
            name: "Saturn",
            type: .planet,
            uvIndex: 1,
            distanceFromSun: 9.54,
            description: "Ringed gas giant",
            funFact: "Low UV at the cloud tops, but you'd need to worry more about the hexagonal storms and rings! 🪐💍"
        ),
        
        CelestialBody(
            name: "Uranus",
            type: .planet,
            uvIndex: 0,
            distanceFromSun: 19.2,
            description: "Ice giant tilted on its side",
            funFact: "Practically no UV reaching the cloud tops - it's basically permanent winter in space! 🔵❄️"
        ),
        
        CelestialBody(
            name: "Neptune",
            type: .planet,
            uvIndex: 0,
            distanceFromSun: 30.1,
            description: "Furthest gas giant with extreme winds",
            funFact: "Almost no UV, but winds up to 2,100 km/h would be your bigger concern! 🔵💨"
        ),
        
        // MARK: - Moon
        CelestialBody(
            name: "The Moon",
            type: .moon,
            uvIndex: 50,
            description: "Earth's natural satellite",
            funFact: "No atmosphere means full space UV hits the surface - lunar tourists need serious sunscreen! 🌙☀️"
        ),
        
        // MARK: - Space Stations
        CelestialBody(
            name: "International Space Station (ISS)",
            type: .spaceStation,
            uvIndex: 50,
            description: "Largest human-made object in space",
            yearLaunched: 1998,
            orbitType: "Low Earth Orbit (LEO)",
            funFact: "Largest human-made object in space! Continuously crewed since 2000 - astronauts get serious UV exposure! 🚀👨‍🚀"
        ),
        
        CelestialBody(
            name: "Tiangong Space Station",
            type: .spaceStation,
            uvIndex: 50,
            description: "China's permanent modular space station",
            yearLaunched: 2021,
            orbitType: "Low Earth Orbit (LEO)",
            funFact: "China's permanent modular space station - taikonauts experience the same intense space UV as ISS crew! 🚀🇨🇳"
        ),
        
        // MARK: - Satellites
        CelestialBody(
            name: "Hubble Space Telescope",
            type: .telescope,
            uvIndex: 50,
            description: "Iconic space telescope in low Earth orbit",
            yearLaunched: 1990,
            orbitType: "LEO (~540 km)",
            funFact: "Still taking amazing photos after 30+ years! Those iconic images of the Pillars of Creation! 🔭✨"
        ),
        
        CelestialBody(
            name: "James Webb Space Telescope",
            type: .telescope,
            uvIndex: 50,
            description: "Most powerful space telescope ever built",
            yearLaunched: 2021,
            orbitType: "Sun-Earth L2 Point",
            funFact: "Observing the universe's first galaxies from 1.5 million km away - the ultimate deep space photographer! 🔭🌌"
        ),
        
        CelestialBody(
            name: "GOES-16 (GOES-East)",
            type: .satellite,
            uvIndex: 50,
            description: "Weather monitoring satellite for the Americas",
            yearLaunched: 2016,
            orbitType: "Geostationary",
            funFact: "Your weather forecast's best friend! Monitors hurricanes and storms over the Americas 24/7! 🛰️🌀"
        ),
        
        CelestialBody(
            name: "GOES-18 (GOES-West)",
            type: .satellite,
            uvIndex: 50,
            description: "Weather monitoring satellite for the Pacific",
            yearLaunched: 2022,
            orbitType: "Geostationary",
            funFact: "The Pacific weather watcher! Keeps an eye on Alaska and the western U.S. from space! 🛰️🌊"
        ),
        
        CelestialBody(
            name: "Terra Satellite",
            type: .satellite,
            uvIndex: 50,
            description: "NASA's flagship Earth observation satellite",
            yearLaunched: 1999,
            orbitType: "Sun-synchronous LEO",
            funFact: "NASA's flagship Earth observer! It's been watching our planet's climate for over 20 years! 🛰️🌍"
        ),
        
        CelestialBody(
            name: "Aqua Satellite",
            type: .satellite,
            uvIndex: 50,
            description: "Water cycle monitoring satellite",
            yearLaunched: 2002,
            orbitType: "Sun-synchronous LEO",
            funFact: "The water cycle detective! Monitors Earth's oceans, ice, and atmosphere from space! 🛰️💧"
        ),
        
        CelestialBody(
            name: "Landsat 8",
            type: .satellite,
            uvIndex: 50,
            description: "Long-running Earth imaging satellite",
            yearLaunched: 2013,
            orbitType: "Sun-synchronous LEO",
            funFact: "Continues 50+ years of Earth imaging! Your Google Earth images probably came from here! 🛰️📸"
        ),
        
        CelestialBody(
            name: "Sentinel-2A",
            type: .satellite,
            uvIndex: 50,
            description: "High-resolution Earth observation satellite",
            yearLaunched: 2015,
            orbitType: "Sun-synchronous LEO",
            funFact: "ESA's high-res Earth photographer! Takes incredibly detailed shots for environmental monitoring! 🛰️🔍"
        ),
        
        CelestialBody(
            name: "Sentinel-2B",
            type: .satellite,
            uvIndex: 50,
            description: "Twin satellite for global Earth monitoring",
            yearLaunched: 2017,
            orbitType: "Sun-synchronous LEO",
            funFact: "Sentinel-2A's twin! Together they photograph the entire Earth every 5 days! 🛰️👯‍♀️"
        ),
        
        CelestialBody(
            name: "Starlink-30000",
            type: .satellite,
            uvIndex: 50,
            description: "Internet constellation satellite",
            yearLaunched: 2019,
            orbitType: "LEO (~550 km)",
            funFact: "One of thousands in SpaceX's internet constellation! Bringing WiFi to everywhere on Earth! 🛰️📶"
        )
    ]
    
    private init() {}
    
    func searchCelestialBodies(query: String) -> [CelestialBody] {
        guard !query.isEmpty else { return [] }
        
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return exact matches first, then partial matches
        let exactMatches = celestialBodies.filter { body in
            body.name.lowercased() == normalizedQuery
        }
        
        let partialMatches = celestialBodies.filter { body in
            body.name.lowercased() != normalizedQuery && 
            body.name.lowercased().contains(normalizedQuery)
        }
        
        // Special search terms
        let keywordMatches = celestialBodies.filter { body in
            !exactMatches.contains(body) && !partialMatches.contains(body) && (
                (normalizedQuery.contains("space") && (body.type == .spaceStation || body.type == .satellite || body.type == .telescope)) ||
                (normalizedQuery.contains("planet") && body.type == .planet) ||
                (normalizedQuery.contains("satellite") && body.type == .satellite) ||
                (normalizedQuery.contains("telescope") && body.type == .telescope) ||
                (normalizedQuery.contains("station") && body.type == .spaceStation) ||
                (normalizedQuery.contains("iss") && body.name.contains("ISS")) ||
                (normalizedQuery.contains("hubble") && body.name.contains("Hubble")) ||
                (normalizedQuery.contains("webb") && body.name.contains("Webb")) ||
                (normalizedQuery.contains("moon") && body.type == .moon)
            )
        }
        
        return exactMatches + partialMatches + keywordMatches
    }
    
    func getAllCelestialBodies() -> [CelestialBody] {
        return celestialBodies
    }
}
