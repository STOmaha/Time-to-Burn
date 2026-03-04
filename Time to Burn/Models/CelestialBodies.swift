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
    let timeToBurn: String // Hard-coded burn time for Type I skin
    let distanceFromSun: Double? // AU (Astronomical Units)
    let description: String
    let yearLaunched: Int? // For satellites/stations
    let orbitType: String? // For satellites
    let funFact: String
    
    init(name: String, type: CelestialBodyType, uvIndex: Int, timeToBurn: String, distanceFromSun: Double? = nil, description: String, yearLaunched: Int? = nil, orbitType: String? = nil, funFact: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.uvIndex = uvIndex
        self.timeToBurn = timeToBurn
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
            case "the sun", "sun": return "☀️"
            case "mercury": return "☿️"
            case "venus": return "♀️"
            case "mars": return "♂️"
            case "jupiter": return "♃"
            case "saturn": return "♄"
            case "uranus": return "♅"
            case "neptune": return "♆"
            case "pluto": return "♇"
            default: return "☀️"
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
        // MARK: - The Sun
        CelestialBody(
            name: "The Sun",
            type: .planet, // Using planet type for solar objects
            uvIndex: 999,
            timeToBurn: "Instant Vaporization",
            distanceFromSun: 0.0,
            description: "Our star - the ultimate UV source",
            funFact: "☀️ INFINITE UV! The source of all solar system UV! 🔥🔥🔥"
        ),
        
        // MARK: - Planets
        CelestialBody(
            name: "Mercury",
            type: .planet,
            uvIndex: 334,
            timeToBurn: "10 seconds",
            distanceFromSun: 0.387,
            description: "Closest planet to the Sun",
            funFact: "Extreme. SPF numbers don't mean much here, you'll be crispy in under 30 seconds!"
        ),
        
        CelestialBody(
            name: "Venus",
            type: .planet,
            uvIndex: 0,
            timeToBurn: "Never (UV blocked)",
            distanceFromSun: 0.723,
            description: "Thick sulfuric acid clouds block all UV",
            funFact: "'UV? Nope.' Thick atmosphere of clouds prevents UV from getting to the ground. But you can still get heat stroke as the surface is 867°F (464°C) - consistently toasty everywhere"
        ),
        
        CelestialBody(
            name: "Mars",
            type: .planet,
            uvIndex: 17,
            timeToBurn: "3 minutes",
            distanceFromSun: 1.524,
            description: "Thin atmosphere offers little UV protection",
            funFact: "At the equator it's surface temperature is 70ºF (20ºC), but only 6 feet (1.5m) off the ground and it's 32ºF (0ºC), bring flip flops, sunscreen, and a winter coat!"
        ),
        
        CelestialBody(
            name: "Jupiter",
            type: .planet,
            uvIndex: 1,
            timeToBurn: "2 hours",
            distanceFromSun: 5.20,
            description: "Gas giant with thick atmosphere",
            funFact: "The largest planet, so big you could fit all the other planets inside it, just like your mom."
        ),
        
        CelestialBody(
            name: "Saturn",
            type: .planet,
            uvIndex: 1,
            timeToBurn: "4 hours",
            distanceFromSun: 9.54,
            description: "Ringed gas giant",
            funFact: "Its famous rings are mostly ice and rock, but don't tell Saturn that, it thinks they're real."
        ),
        
        CelestialBody(
            name: "Uranus",
            type: .planet,
            uvIndex: 0,
            timeToBurn: "Where the Sun don't shine. 😉",
            distanceFromSun: 19.2,
            description: "Ice giant tilted on its side",
            funFact: "Rotating at a (98° tilt), likely due to a massive ancient collision. with your mom."
        ),
        
        CelestialBody(
            name: "Neptune",
            type: .planet,
            uvIndex: 0,
            timeToBurn: "Wind-Burns will get you first.",
            distanceFromSun: 30.1,
            description: "Furthest gas giant with extreme winds",
            funFact: "The hurricanes here aren't beach weather. 🌀 You're more likely to be blown away by 1,200 mph (2,000 km/h) winds than get a sunburn!"
        ),
        
        CelestialBody(
            name: "Pluto",
            type: .planet,
            uvIndex: 0,
            timeToBurn: "Never (bring a parka)",
            distanceFromSun: 39.0,
            description: "Dwarf planet in the outer solar system",
            funFact: "Though reclassified as a dwarf planet, it has five moons, and its largest, Charon, is so big that together they act like a double planet."
        ),
        
        // MARK: - Moon
        CelestialBody(
            name: "The Moon",
            type: .moon,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Earth's natural satellite",
            funFact: "🌙 Extreme (space-level UV at noon). 🔥 Protection: visor + space suit. Neil Armstrong didn't just need courage—he needed SPF ∞! The ultimate space sunbathing destination! 🚀☀️"
        ),
        
        // MARK: - Space Stations
        CelestialBody(
            name: "International Space Station (ISS)",
            type: .spaceStation,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Largest human-made object in space",
            yearLaunched: 1998,
            orbitType: "Low Earth Orbit (LEO)",
            funFact: "Largest human-made object in space! Continuously crewed since 2000 - astronauts get serious UV exposure! 🚀👨‍🚀"
        ),
        
        CelestialBody(
            name: "Tiangong Space Station",
            type: .spaceStation,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
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
            timeToBurn: "90 Seconds",
            description: "Iconic space telescope in low Earth orbit",
            yearLaunched: 1990,
            orbitType: "LEO (~540 km)",
            funFact: "Still taking amazing photos after 30+ years! Those iconic images of the Pillars of Creation! 🔭✨"
        ),
        
        CelestialBody(
            name: "James Webb Space Telescope",
            type: .telescope,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Most powerful space telescope ever built",
            yearLaunched: 2021,
            orbitType: "Sun-Earth L2 Point",
            funFact: "Observing the universe's first galaxies from 1.5 million km away - the ultimate deep space photographer! 🔭🌌"
        ),
        
        CelestialBody(
            name: "GOES-16 (GOES-East)",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Secondss",
            description: "Weather monitoring satellite for the Americas",
            yearLaunched: 2016,
            orbitType: "Geostationary",
            funFact: "Your weather forecast's best friend! Monitors hurricanes and storms over the Americas 24/7! 🛰️🌀"
        ),
        
        CelestialBody(
            name: "GOES-18 (GOES-West)",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Weather monitoring satellite for the Pacific",
            yearLaunched: 2022,
            orbitType: "Geostationary",
            funFact: "The Pacific weather watcher! Keeps an eye on Alaska and the western U.S. from space! 🛰️🌊"
        ),
        
        CelestialBody(
            name: "Terra Satellite",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "NASA's flagship Earth observation satellite",
            yearLaunched: 1999,
            orbitType: "Sun-synchronous LEO",
            funFact: "NASA's flagship Earth observer! It's been watching our planet's climate for over 20 years! 🛰️🌍"
        ),
        
        CelestialBody(
            name: "Aqua Satellite",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Water cycle monitoring satellite",
            yearLaunched: 2002,
            orbitType: "Sun-synchronous LEO",
            funFact: "The water cycle detective! Monitors Earth's oceans, ice, and atmosphere from space! 🛰️💧"
        ),
        
        CelestialBody(
            name: "Landsat 8",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Long-running Earth imaging satellite",
            yearLaunched: 2013,
            orbitType: "Sun-synchronous LEO",
            funFact: "Continues 50+ years of Earth imaging! Your Google Earth images probably came from here! 🛰️📸"
        ),
        
        CelestialBody(
            name: "Sentinel-2A",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "High-resolution Earth observation satellite",
            yearLaunched: 2015,
            orbitType: "Sun-synchronous LEO",
            funFact: "ESA's high-res Earth photographer! Takes incredibly detailed shots for environmental monitoring! 🛰️🔍"
        ),
        
        CelestialBody(
            name: "Sentinel-2B",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
            description: "Twin satellite for global Earth monitoring",
            yearLaunched: 2017,
            orbitType: "Sun-synchronous LEO",
            funFact: "Sentinel-2A's twin! Together they photograph the entire Earth every 5 days! 🛰️👯‍♀️"
        ),
        
        CelestialBody(
            name: "Starlink-30000",
            type: .satellite,
            uvIndex: 50,
            timeToBurn: "90 Seconds",
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
                (normalizedQuery.contains("solar system") && body.type == .planet) ||
                (normalizedQuery.contains("solar") && body.type == .planet) ||
                (normalizedQuery.contains("system") && body.type == .planet) ||
                (normalizedQuery.contains("sun") && body.name.lowercased().contains("sun")) ||
                (normalizedQuery.contains("satellite") && body.type == .satellite) ||
                (normalizedQuery.contains("telescope") && body.type == .telescope) ||
                (normalizedQuery.contains("station") && body.type == .spaceStation) ||
                (normalizedQuery.contains("iss") && body.name.contains("ISS")) ||
                (normalizedQuery.contains("hubble") && body.name.contains("Hubble")) ||
                (normalizedQuery.contains("webb") && body.name.contains("Webb")) ||
                (normalizedQuery.contains("moon") && body.type == .moon) ||
                (normalizedQuery.contains("uv") && body.uvIndex > 50) || // High UV bodies
                (normalizedQuery.contains("extreme") && body.uvIndex > 50) ||
                (normalizedQuery.contains("burn") && body.uvIndex > 10) ||
                (normalizedQuery.contains("dangerous") && body.uvIndex > 100)
            )
        }
        
        return exactMatches + partialMatches + keywordMatches
    }
    
    func getAllCelestialBodies() -> [CelestialBody] {
        return celestialBodies
    }
}
