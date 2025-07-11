import Foundation
import ActivityKit

struct UVExposureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var totalExposureTime: TimeInterval
        var isTimerRunning: Bool
        var lastSunscreenApplication: Date?
        var uvChangeNotification: String?
        var sunscreenTimerRemaining: TimeInterval
        var isSunscreenActive: Bool
        var exposureProgress: Double
        var shouldShowSunscreenPrompt: Bool
        var sunscreenExpirationTime: Date?
        var sunscreenProgress: Double
        var currentUVIndex: Int
        var currentUVColor: String
    }
    
    var uvIndex: Int
    var maxExposureTime: Int
    var sunscreenReapplyTime: Date
} 
