import Foundation
import SwiftUI

// MARK: - Lightweight Widget-Only Models
// These models mirror the main app's SharedModels but without WeatherKit dependency
// to keep widget memory usage low (widgets have ~30MB limit)

struct UVData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let uvIndex: Int
    let cloudCover: Double
    let cloudCondition: String

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case uvIndex = "value"
        case cloudCover
        case cloudCondition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both cases: with id and without id (for backwards compatibility)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.date = try container.decode(Date.self, forKey: .date)
        self.uvIndex = try container.decode(Int.self, forKey: .uvIndex)
        self.cloudCover = (try? container.decode(Double.self, forKey: .cloudCover)) ?? 0
        self.cloudCondition = (try? container.decode(String.self, forKey: .cloudCondition)) ?? "Clear"
    }

    init(uvIndex: Int, date: Date, cloudCover: Double = 0, cloudCondition: String = "Clear") {
        self.id = UUID()
        self.date = date
        self.uvIndex = uvIndex
        self.cloudCover = cloudCover
        self.cloudCondition = cloudCondition
    }
}

struct SharedUVData: Codable {
    let currentUVIndex: Int
    let timeToBurn: Int
    let elapsedTime: TimeInterval
    let totalExposureTime: TimeInterval
    let isTimerRunning: Bool
    let lastSunscreenApplication: Date?
    let sunscreenReapplyTimeRemaining: TimeInterval
    let exposureStatus: ExposureStatus
    let exposureProgress: Double
    let timestamp: Date
    let locationName: String
    let lastUpdated: Date
    let hourlyUVData: [UVData]?
    let currentCloudCover: Double
    let currentCloudCondition: String

    enum ExposureStatus: String, Codable, CaseIterable {
        case safe = "Safe"
        case warning = "Warning"
        case exceeded = "Exceeded"
        case noUV = "No UV"

        var color: Color {
            switch self {
            case .safe: return .green
            case .warning: return .orange
            case .exceeded: return .red
            case .noUV: return .blue
            }
        }
    }
}

// MARK: - Lightweight Shared Data Manager for Widget
// Avoids singletons and ObservableObject overhead

struct WidgetDataLoader {
    private static let appGroupID = "group.com.anvilheadstudios.timetoburn"
    private static let dataKey = "sharedUVData"

    static func loadSharedData() -> SharedUVData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: dataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedUVData.self, from: data)
    }
}
